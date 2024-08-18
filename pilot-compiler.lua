#!/usr/bin/env lua

local REQS_TBL_NAME = "__reqs__"
local KEYWORDS = { "and", "break", "do", "else", "elseif", "end", "false", "for", "function", "if", "in", "local",
	"nil", "not", "or", "repeat", "return", "then", "true", "until", "while", "continue", "goto" }
local REQ_LINE_PAT = "(\n[ \t]*local%s+[%a_][%w_]*%s*=%s*)require%(%s*[\'\"](.-)[\'\"]%s*%)"
local SUFFIXES = {
	".lua",
	".luau",
	".json",
	"/init.lua",
	"/init.luau",
}

local decodeJson = require("dkjson").decode
local fileExists = require("pl.path").exists
local readFile = require("pl.utils").readfile
local find = require("pl.tablex").find


local function join(tbl1, tbl2)
	for _, val in ipairs(tbl2) do
		table.insert(tbl1, val)
	end
end


local function serialize(thing, isKey)
	local typ = type(thing)
	if typ == "string" then
		if isKey and thing:find("^[%a_][%w_]*$") and not find(KEYWORDS, thing) then
			return thing
		else
			return string.format(isKey and "[%q]" or "%q", thing)
		end
	elseif typ == "number" or typ == "boolean" then
		return string.format(isKey and "[%s]" or "%s", thing)
	elseif typ == "table" then
		assert(not isKey)

		local used = {}
		local items = {}

		for i, val in ipairs(thing) do
			table.insert(items, serialize(val, false))
			used[i] = true
		end

		for key, val in pairs(thing) do
			if not used[key] then
				table.insert(items, serialize(key, true) .. "=" .. serialize(val, false))
			end
		end

		return "{" .. table.concat(items, ",") .. "}"
	end

	return error("unreachable reached")
end


local function normalizeModuleName(moduleName)
	for _, suffix in ipairs(SUFFIXES) do
		local filename = moduleName .. suffix
		if fileExists(filename) then
			return filename
		end
	end

	return nil
end

local function preprocessFile(contents)
	contents = "\n" .. contents

	local requires = {}
	local newContent = contents:gsub(REQ_LINE_PAT, function(prefix, moduleName)
		local normalized = normalizeModuleName(moduleName)
		if not normalized then
			return nil
		end

		table.insert(requires, normalized)
		return prefix .. string.format("%s[%q]", REQS_TBL_NAME, normalized)
	end)
	table.sort(requires)

	return newContent:sub(2), requires -- Remove the leading newline
end

local function getFileContentsAsExpression(contents, filename)
	if filename:find("%.luau?$") then
		return string.format("(function()\n%s\nend)()", contents)
	else
		local decoded, _, err = decodeJson(contents)
		assert(decoded, "error while reading JSON: " .. tostring(err))
		return serialize(decoded)
	end
end

local function getComponents(fileName, requiring, required)
	table.insert(requiring, fileName)

	local rawContent = assert(readFile(fileName), "no such module: " .. fileName)
	local newContent, deps = preprocessFile(rawContent)
	local expression = getFileContentsAsExpression(newContent, fileName, deps)

	local buf = {}
	for _, dep in ipairs(deps) do
		if find(requiring, dep) then
			error("cyclic require between: " .. table.concat(requiring, " <-> "))
		end

		if not required[dep] then
			join(buf, getComponents(dep, requiring, required))
		end
	end

	table.insert(buf, string.format("%s[%q] = %s", REQS_TBL_NAME, fileName, expression))

	assert(table.remove(requiring) == fileName)
	required[fileName] = true

	return buf
end

local function compile(filename)
	local buf = getComponents(filename, {}, {})
	table.insert(buf, 1, string.format("local %s = {}", REQS_TBL_NAME))
	return table.concat(buf, "\n\n")
end


if pcall(debug.getlocal, 4, 1) then
	return compile -- Was require()d, not ran directly
end

local inName = arg[1]
if not inName then
	io.stdout:write("usage: pilot-compiler.lua <source-file>\n")
	os.exit()
end
assert(type(inName) == "string", "missing <source-file>")

io.stdout:write(compile(inName))
return compile

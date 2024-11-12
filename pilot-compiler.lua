#!/usr/bin/env lua

local MODULES_TBL_NAME = "__pcmodules__"
local KEYWORDS = { "and", "break", "do", "else", "elseif", "end", "false", "for", "function", "if", "in", "local",
	"nil", "not", "or", "repeat", "return", "then", "true", "until", "while", "continue", "goto" }
local SUFFIXES = {
	".lua",
	".luau",
	".json",
	"/init.lua",
	"/init.luau",
}

local lexer = require("pl.lexer")
local json = require("dkjson")
local find = require("pl.tablex").find


local function join(tbl1, tbl2)
	for _, val in ipairs(tbl2) do
		table.insert(tbl1, val)
	end
end

local function readFile(filename)
	local file = io.open(filename)
	if not file then
		return nil
	end

	local data = file:read("*a")
	file:close()
	return data
end

local function normalizePath(path)
	local normalized = {}
	for component in string.gmatch(path, "[^/\\]+") do
		if component == ".." then
			table.remove(normalized)
		elseif component ~= "" and component ~= "." then
			table.insert(normalized, component)
		end
	end
	if #normalized == 0 then
		table.insert(normalized, ".")
	end

	return table.concat(normalized, "/")
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
		return string.format(isKey and "[%s]" or "%s", tostring(thing))
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

local function evalString(str)
	local loaded = (loadstring or load)("return " .. str)
	return loaded and loaded() or ""
end


local function normalizeModuleName(moduleName)
	for _, suffix in ipairs(SUFFIXES) do
		local filename = moduleName .. suffix

		if readFile(filename) then
			return normalizePath(filename)
		end
	end

	return nil
end

local function preprocessFile(contents)
	local buf = {}
	local requires = {}

	local iter = lexer.lua(contents, {}, {})

	local function consumeInsignificant(minibuf)
		local nTyp, nToken
		repeat
			nTyp, nToken = iter()
			table.insert(minibuf, nToken)
		until not (nTyp == "space" or nTyp == "comment")

		return nTyp
	end

	local function parseRequire(minibuf)
		local hasBracket = false

		local stoppedToken = consumeInsignificant(minibuf)
		if stoppedToken == "(" then
			hasBracket = true
			stoppedToken = consumeInsignificant(minibuf)
		end

		if stoppedToken ~= "string" then
			return minibuf
		end

		local moduleName = evalString(minibuf[#minibuf])
		local normalized = normalizeModuleName(moduleName)
		table.insert(requires, normalized) -- Normalized may be nil, but that's ok

		if not normalized or (hasBracket and consumeInsignificant(minibuf) ~= ")") then
			return minibuf
		else
			return { string.format("%s[%q]", MODULES_TBL_NAME, normalized) }
		end
	end

	while true do
		local typ, token = iter()
		if not typ then
			break
		end

		if typ == "iden" and token == "require" then
			join(buf, parseRequire({token}))
		else
			table.insert(buf, token)
		end
	end

	return table.concat(buf), requires
end

local function getFileContentsAsExpression(contents, fileName)
	if fileName:find("%.luau?$") then
		return string.format("(function()\n%s\nend)()", contents)
	else
		local decoded, _, err = json.decode(contents)
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

	table.insert(buf, string.format("%s[%q] = %s", MODULES_TBL_NAME, fileName, expression))

	assert(table.remove(requiring) == fileName)
	required[fileName] = true

	return buf
end

local function compile(filename)
	local buf = getComponents(filename, {}, {})
	table.insert(buf, 1, string.format("local %s = {}", MODULES_TBL_NAME))
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

#!/usr/bin/env lua

local REQS_TBL_NAME = "__reqs__"
local KEYWORDS = { "and", "break", "do", "else", "elseif", "end", "false", "for", "function", "if", "in", "local",
	"nil", "not", "or", "repeat", "return", "then", "true", "until", "while", "continue", "goto" }


local decodeJson, readFile, find, getSelectedScript
if not game then
	decodeJson = require("dkjson").decode
	readFile = require("pl.utils").readfile
	find = require("pl.tablex").find
	getSelectedScript = nil -- Not used by the stock Lua version
else
	local HttpService = game:GetService("HttpService")
	local Selection = game:GetService("Selection")

	function decodeJson(str)
		return HttpService:JSONDecode(str)
	end

	local function isScript(thing)
		return thing:IsA("ModuleScript")
	end

	function getSelectedScript()
		local sel = Selection:Get()[1]
		if #sel ~= 1 then
			return nil, "unable to determine root; make sure you have only one thing selected"
		elseif not isScript(sel[1]) then
			return nil, "selection must be a ModuleScript"
		end

		return sel
	end

	function readFile(path)
		local selected, err = getSelectedScript()
		if not selected then
			return nil, err
		end

		local cur = selected.Parent

		for component in string.gmatch(path, "[^/\\]+") do
			cur = cur:FindFirstChild(component)
			if not cur then
				return nil, "cannot find file: " .. component
			end
		end

		if not isScript(cur) then
			return nil, "file is not a ModuleScript: " .. path
		end

		return cur.Source, nil
	end

	find = table.find
end


local function join(tbl1, tbl2)
	for _, val in ipairs(tbl2) do
		table.insert(tbl1, val)
	end
end

local function isLua(filename)
	return filename:find("%.luau?$") ~= nil
end

local function isJson(filename)
	return filename:find("%.json$") ~= nil
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


local function parseInfoString(contents)
	local infoString, newContents = contents:match("^%-%-%[%[!(.+)%]%]\n?(.*)")
	if not infoString then
		return {}, contents
	end

	local requires = {}
	for args in string.gmatch(infoString, "\n%s*req:%s+([^\r\n]+)") do
		local alias, moduleName = args:match("^([%a_][%w_]*)%s+=%s+(%S+)")
		assert(alias and moduleName, "malformed req line: " .. args)

		if not isLua(moduleName) and not isJson(moduleName) then
			moduleName = moduleName:gsub("/?$", "/init.lua")
		end

		table.insert(requires, {moduleName, alias})
	end
	table.sort(requires, function(a, b) return a[1] < b[1] end)

	return requires, newContents
end

local function getFileContentsAsExpression(contents, filename, requires)
	if isLua(filename) then
		local buf = { "(function()\n" }
		for _, reqInfo in ipairs(requires) do
			table.insert(buf, string.format("local %s = %s[%q]\n", reqInfo[2], REQS_TBL_NAME, reqInfo[1]))
		end
		table.insert(buf, contents)
		table.insert(buf, "\nend)()")
		return table.concat(buf)
	else
		local decoded, _, err = decodeJson(contents)
		assert(decoded, "error while reading JSON: " .. tostring(err))

		return serialize(decoded)
	end
end

local function getComponents(moduleName, parentName, requiring, required)
	table.insert(requiring, moduleName)

	local rawContent = assert(readFile(moduleName), parentName .. ": no such file: " .. moduleName)
	local requires, newContent = parseInfoString(rawContent)
	local expression = getFileContentsAsExpression(newContent, moduleName, requires)

	local buf = {}
	for _, reqInfo in ipairs(requires) do
		local reqModuleName = reqInfo[1]

		if find(requiring, reqModuleName) then
			error("cyclic require between: " .. table.concat(requiring, " <-> "))
		end

		if not required[reqModuleName] then
			join(buf, getComponents(reqModuleName, moduleName, requiring, required))
		end
	end

	table.insert(buf, string.format("%s[%q] = %s", REQS_TBL_NAME, moduleName, expression))

	assert(table.remove(requiring) == moduleName)
	required[moduleName] = true

	return buf
end

local function compile(filename)
	local buf = getComponents(filename, "<ROOT>", {}, {})
	table.insert(buf, 1, string.format("local %s = {}", REQS_TBL_NAME))
	return table.concat(buf, "\n\n")
end


if not game then
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
else
	local selected, err = getSelectedScript()
	if not selected then
		print("usage: select a ModuleScript to compile, then try again (" .. err .. ")")
		return nil
	end

	return compile(selected.Name)
end

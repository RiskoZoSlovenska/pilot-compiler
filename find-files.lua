#!/bin/env lua

local NAME = "find-files.lua"
local VERSION = "0.0.1"

local options = {}
local stack = {}
for _, input in ipairs(arg) do
	local option = input:match("^%-%-(.+)")
	if option then
		options[option] = true
	else
		table.insert(stack, input)
	end
end

if options.version then
	io.write(VERSION .. "\n")
	os.exit()
elseif options.help then
	io.write("Usage: " .. NAME .. " [--help] [--version] [--lua|--bin] packages...")
end
if not (options.lua or options.bin) then
	options.lua = true
	options.bin = true
end


local function execute(cmd, ...)
	cmd = string.format(cmd, ...)

	local file = assert(io.popen(cmd))
	local data = assert(file:read("*a"))
	assert(file:close(), "command failed: " .. cmd)
	return data
end

local function splitIter(str)
	return string.gmatch(str, "[^\r\n]+")
end


local luaModules = {}
local binModules = {}
local seenPkgs = {}

local function processPkg(pkg)
	for mod in splitIter(execute("luarocks show --modules %s", pkg)) do
		if not luaModules[mod] and not binModules[mod] then
			luaModules[mod] = package.searchpath(mod, package.path)
			binModules[mod] = package.searchpath(mod, package.cpath)
			assert(luaModules[mod] or binModules[mod], "unable to find file for module " .. mod)
		end
	end

	for dep in splitIter(execute("luarocks show --deps %s", pkg)) do
		dep = dep:match("^%S+")
		if dep ~= "lua" then
			table.insert(stack, dep)
		end
	end
end

while stack[1] do
	local pkg = table.remove(stack)
	if not seenPkgs[pkg] then
		seenPkgs[pkg] = true
		processPkg(pkg)
	end
end



local out = {}

if options.lua then
	for _, v in pairs(luaModules) do
		table.insert(out, v)
	end
end
if options.bin then
	for _, v in pairs(binModules) do
		table.insert(out, v)
	end
end

io.write(table.concat(out, " ") .. "\n")

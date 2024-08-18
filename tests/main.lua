--[[!
	req: mod1 = mod1.lua
	req: foo = pkg1
	req: foo2  =	pkg1/
]]

print(mod1.add(foo.a, foo.b))

local mod1 = require("mod1")
local foo  = require("pkg1")
local foo2 = require("pkg1")

print(mod1.add(foo.a, foo.b))

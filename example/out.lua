keyword	local
space	 
iden	mod1
space	 
=	=
space	 
iden	require
(	(
string	"mod1"
)	)
space	

keyword	local
space	 
iden	foo
space	 
=	=
space	 
iden	require
(	(
string	"pkg1"
)	)
space	 
comment	-- what

keyword	local
space	 
iden	foo2
space	 
=	=
space	 
iden	require
(	(
string	"pkg1"
)	)
space	


iden	print
(	(
iden	mod1
.	.
iden	add
(	(
iden	foo
.	.
iden	a
,	,
space	 
iden	foo
.	.
iden	b
)	)
)	)
space	

keyword	return
space	 
{	{
space	
	
iden	add
space	 
=	=
space	 
keyword	function
(	(
iden	a
,	,
space	 
iden	b
)	)
space	
		
keyword	return
space	 
iden	a
space	 
+	+
space	 
iden	b
space	
	
keyword	end
,	,
space	

}	}
space	

keyword	local
space	 
iden	a
space	 
=	=
space	 
iden	require
(	(
string	"pkg1/a"
)	)
space	

keyword	local
space	 
iden	b
space	 
=	=
space	 
iden	require
(	(
string	"pkg1/b"
)	)
space	


keyword	return
space	 
{	{
space	 
iden	a
space	 
=	=
space	 
iden	a
,	,
space	 
iden	b
space	 
=	=
space	 
iden	b
.	.
iden	foo
space	 
}	}
space	

keyword	local
space	 
iden	lua
space	 
=	=
space	 
iden	require
(	(
string	"mod1"
)	)
space	

comment	--local lol = require("main.lua")

space	

keyword	return
space	 
number	1
space	

{	{
space	
	
string	"foo"
:	:
space	 
number	3
,	,
space	
	
string	"nil"
:	:
space	 
keyword	true
,	,
space	
	
string	"aaaa"
:	:
space	 
[	[
number	1
,	,
space	 
number	2
,	,
space	 
number	3
,	,
space	 
iden	null
,	,
space	 
number	5
,	,
space	 
number	6
]	]
,	,
space	
	
string	"_bar"
:	:
space	 
iden	null
,	,
space	
	
string	"epi\nc"
:	:
space	 
string	"co\nol"
space	

}	}
space	

local __reqs__ = {}

__reqs__["mod1.lua"] = (function()
return {
	add = function(a, b)
		return a + b
	end,
}

end)()

__reqs__["pkg1/a.luau"] = (function()
local lua = __reqs__["mod1.lua"]
--local lol = require("main.lua")

return 1

end)()

__reqs__["pkg1/b.json"] = {["epi\
c"]="co\
ol",["nil"]=true,aaaa={1,2,3,[5]=5,[6]=6},foo=3}

__reqs__["pkg1/init.lua"] = (function()
local a = __reqs__["pkg1/a.luau"]
local b = __reqs__["pkg1/b.json"]

return { a = a, b = b.foo }

end)()

__reqs__["main.lua"] = (function()
local mod1 = __reqs__["mod1.lua"]
local foo = __reqs__["pkg1/init.lua"] -- what
local foo2 = __reqs__["pkg1/init.lua"]

print(mod1.add(foo.a, foo.b))

end)()
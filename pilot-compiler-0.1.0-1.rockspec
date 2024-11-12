package = "pilot-compiler"
version = "0.1.0-1"
source = {
	url = "git+http://github.com/RiskoZoSlovenska/pilot-compiler",
}
description = {
	summary = "",
	homepage = "http://github.com/RiskoZoSlovenska/pilot-compiler",
	license = "MIT"
}
dependencies = {
	"lua >= 5.1, <= 5.4",
	"penlight",
	"dkjson",
	"lfs",
}
build = {
	type = "builtin",
	modules = {
		["pilot-compiler"] = "pilot-compiler.lua"
	},
	install = {
		bin = {
			["pilot-compiler"] = "pilot-compiler.lua"
		},
	},
}

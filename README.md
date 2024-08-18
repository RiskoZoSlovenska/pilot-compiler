# pilot-compiler

A rudimentary compiler to bunch multiple Lua(u) files into one, mainly for use in Waste of Space.

The compiler takes an input file and searches for `require` statements. It tries to resolve each module name to a file on the filesystem, and if it succeeds, inserts the required file into the main file and replaces the `require` with a reference to the module's return value. This is done recursively, allowing the compiler to pack an entire project into a single file. `require` statements that don't match a file are left as-is, allowing the use of built-in modules such as `repr`.

It also supports searching for `/init.lua` files and can also `require` JSON files (by converting them to Lua tables).

For an example, see the `example` directory and try compiling the `main.lua` file.


## Installation and Usage

### LuaRocks

The compiler can be built using [LuaRocks](https://luarocks.org). Clone this repository, install LuaRocks, and then run
```
luarocks make
```
to fetch the dependencies and install the file in your bin directory.

Then, run the compiler via
```
pilot-compiler file.lua
```

### Manual

Ensure you have [dkjson](http://dkolf.de/dkjson-lua/) and [Penlight](http://dkolf.de/dkjson-lua/). Then, simply run via Lua:
```
lua pilot-compiler.lua file.lua
```


### Caveats

1. Hasn't been extensively tested; please report any bugs.

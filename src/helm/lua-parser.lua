















local Peg  = require "espalier:espalier/peg"
local Node = require "espalier:espalier/node"























































































































local Lua = Node : inherit "lua"

function Lua.__tostring(lua)
   return lua:span()
end

local lua_metas = { lua = Lua }



return Peg(lua_str) : toGrammar(lua_metas)

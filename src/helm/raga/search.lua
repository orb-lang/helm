



local table = core.table
local clone, splice = assert(table.clone), assert(table.splice)
local EditBase = require "helm/raga/edit"
local Resbuf = require "helm:buf/resbuf"

local Search = clone(EditBase, 2)

Search.name = "search"
Search.prompt_char = "⁉️"
Search.keymap = require "helm:keymap/search"
Search.target = "agents.search"








function Search.onTxtbufChanged()
   send { to = "agents.search", method = "update" }
   EditBase.onTxtbufChanged()
end









function Search.onShift(modeS)
   EditBase.onShift(modeS)
   modeS:agent'search':update(modeS)
   modeS.zones.command.contents.suggestions = modeS:agent'search':window()
   modeS:bindZone("results", "search", Resbuf, { scrollable = true })
end



return Search


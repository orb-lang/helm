



local table = core.table
local clone, splice = assert(table.clone), assert(table.splice)
local EditBase = require "helm/raga/edit"
local Resbuf = require "helm:buf/resbuf"

local Search = clone(EditBase, 2)

Search.name = "search"
Search.prompt_char = "⁉️"
Search.keymap = require "helm:keymap/search"








function Search.onTxtbufChanged(modeS)
   modeS:agent'search':update(modeS)
end









function Search.onShift(modeS)
   EditBase.onShift(modeS)
   modeS:agent'search':update(modeS)
   modeS.zones.command.contents.suggestions = modeS:agent'search':window()
   modeS:bindZone("results", "search", Resbuf, { scrollable = true })
end



return Search


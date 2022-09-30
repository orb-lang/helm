



local core = require "qor:core"
local clone = assert(core.table.clone)
local EditBase = require "helm/raga/edit"
local Resbuf = require "helm:buf/resbuf"

local Search = clone(EditBase, 2)

Search.name = "search"
Search.prompt_char = "⁉️"
Search.keymap = require "helm:keymap/search"








function Search.onTxtbufChanged()
   send { to = "agents.search", method = "update" }
   EditBase.onTxtbufChanged()
end









function Search.onShift()
   EditBase.onShift()
   send { to = "agents.search", method = "update" }
   -- #todo this messing directly with the Txtbuf is bad
   local txtbuf = send { to = "zones.command", field = "contents" }
   txtbuf.suggestions = send { to = "agents.search", method = "window" }
   send { method = "bindZone",
      "results", "search", Resbuf, { scrollable = true }}
end



return Search


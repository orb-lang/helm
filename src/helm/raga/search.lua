



local core_table = require "core:table"
local clone, splice = assert(core_table.clone), assert(core_table.splice)
local EditBase = require "helm/raga/edit"
local Resbuf = require "helm:buf/resbuf"

local Search = clone(EditBase, 2)

Search.name = "search"
Search.prompt_char = "⁉️"






Search.default_keymaps = {
   { source = "agents.search", name = "keymap_selection" },
   { source = "agents.search", name = "keymap_actions" }
}
splice(Search.default_keymaps, EditBase.default_keymaps)








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


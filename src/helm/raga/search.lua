



local clone = import("core/table", "clone")
local EditBase = require "helm/raga/edit"
local Resbuf = require "helm:buf/resbuf"

local Search = clone(EditBase, 2)

Search.name = "search"
Search.prompt_char = "⁉️"






Search.default_keymaps = {
   { source = "agents.search", name = "keymap_selection" },
   { source = "agents.search", name = "keymap_actions" }
}
local insert = assert(table.insert)
for _, v in ipairs(EditBase.default_keymaps) do
   insert(Search.default_keymaps, v)
end








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


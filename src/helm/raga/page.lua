




local insert = assert(table.insert)
local clone = import("core/table", "clone")
local RagaBase = require "helm:helm/raga/base"



local Page = clone(RagaBase, 2)

Page.name = "page"
Page.prompt_char = "❓"






Page.default_keymaps = {
   { source = "agents.pager", name = "keymap_actions" },
   { source = "agents.pager", name = "keymap_scrolling" }
}
for _, map in ipairs(RagaBase.default_keymaps) do
   insert(Page.default_keymaps, map)
end









function Page.onShift(modeS)
   modeS.zones.popup:show()
end
function Page.onUnshift(modeS)
   modeS.zones.popup:hide()
end



return Page


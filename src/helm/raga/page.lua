




local core_table = require "core:table"
local clone, splice = assert(core_table.clone), assert(core_table.splice)
local RagaBase = require "helm:helm/raga/base"



local Page = clone(RagaBase, 2)

Page.name = "page"
Page.prompt_char = "❓"






Page.default_keymaps = {
   { source = "agents.pager", name = "keymap_actions" },
   { source = "agents.pager", name = "keymap_scrolling" }
}
splice(Page.default_keymaps, RagaBase.default_keymaps)









function Page.onShift(modeS)
   modeS.zones.popup:show()
end
function Page.onUnshift(modeS)
   modeS.zones.popup:hide()
end



return Page


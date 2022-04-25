




local table = core.table
local clone = assert(table.clone)
local RagaBase = require "helm:raga/base"



local Page = clone(RagaBase, 2)

Page.name = "page"
Page.prompt_char = "❓"
Page.keymap = require "helm:keymap/page"









function Page.onShift(modeS)
   modeS.zones.popup:show()
end
function Page.onUnshift(modeS)
   modeS.zones.popup:hide()
end



return Page


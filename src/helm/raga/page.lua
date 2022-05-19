




local table = core.table
local clone = assert(table.clone)
local RagaBase = require "helm:raga/base"



local Page = clone(RagaBase, 2)

Page.name = "page"
Page.prompt_char = "❓"
Page.keymap = require "helm:keymap/page"
Page.target = "agents.pager"









function Page.onShift()
   send { to = "zones.popup", method = "show" }
end
function Page.onUnshift()
   send { to = "zones.popup", method = "hide" }
end



return Page


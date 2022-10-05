




local core = require "qor:core"
local clone = assert(core.table.clone)
local RagaBase = require "helm:raga/base"



local Page = clone(RagaBase, 2)
local send = Page.send

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


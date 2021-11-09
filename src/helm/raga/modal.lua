





local clone = assert(require 'core:table' . clone)
local a = require "anterm:anterm"
local RagaBase = require "helm:raga/base"



local Modal = clone(RagaBase, 2)
Modal.name = "modal"
Modal.prompt_char = " "






Modal.default_keymaps = {
   { source = "agents.modal", name = "keymap_actions" }
}






function Modal.onShift(modeS)
   modeS.zones.modal:show()
end

function Modal.onUnshift(modeS)
   modeS.zones.modal:hide()
end



return Modal


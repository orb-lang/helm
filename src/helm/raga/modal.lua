





local table = core.table
local clone, splice = assert(table.clone), assert(table.splice)
local a = require "anterm:anterm"
local RagaBase = require "helm:raga/base"



local Modal = clone(RagaBase, 2)
Modal.name = "modal"
Modal.prompt_char = " "
Modal.keymap = require "helm:keymap/modal"






function Modal.onShift(modeS)
   modeS.zones.modal:show()
end

function Modal.onUnshift(modeS)
   modeS.zones.modal:hide()
end



return Modal


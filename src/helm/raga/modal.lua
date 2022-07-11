





local table = core.table
local clone, splice = assert(table.clone), assert(table.splice)
local a = require "anterm:anterm"
local RagaBase = require "helm:raga/base"



local Modal = clone(RagaBase, 2)
Modal.name = "modal"
Modal.prompt_char = " "
Modal.keymap = require "helm:keymap/modal"
Modal.target = "agents.modal"






function Modal.onShift()
   send { to = "zones.modal", method = "show" }
end

function Modal.onUnshift()
   send { to = "zones.modal", method = "hide" }
end



return Modal


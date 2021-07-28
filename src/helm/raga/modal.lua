





local clone = assert(require 'core:table' . clone)
local a = require "anterm:anterm"
local RagaBase = require "helm:raga/base"



local Modal = clone(RagaBase, 2)
Modal.name = "modal"
Modal.prompt_char = " "



function Modal.close(maestro, value)
   maestro.agents.modal.model.value = value
   -- #todo shift back to the previous raga--modeS needs to maintain a stack
   maestro.modeS.shift_to = maestro.modeS.raga_default
end





local function _shortcutFrom(button)
   local shortcut_decl = button.text and button.text:match('&([^&])')
   return shortcut_decl and shortcut_decl:lower()
end

function Modal.letterShortcut(maestro, event)
   local model = maestro.agents.modal.model
   local key = event.key:lower()
   for _, button in ipairs(model.buttons) do
      if _shortcutFrom(button) == key then
         return Modal.close(maestro, button.value)
      end
   end
end

function Modal.cancel(maestro, event)
   local model = maestro.agents.modal.model
   for _, button in ipairs(model.buttons) do
      if button.cancel then
         return Modal.close(maestro, button.value)
      end
   end
end

function Modal.acceptDefault(maestro, event)
   local model = maestro.agents.modal.model
   for _, button in ipairs(model.buttons) do
      if button.default then
         return Modal.close(maestro, button.value)
      end
   end
end






local map = {
   ESC = "cancel",
   RETURN = "acceptDefault"
}
for i = 1, 26 do
   map[("abcdefghijklmnopqrstuvwxyz"):sub(i,i)] = "letterShortcut"
end
Modal.default_keymaps = { map }






function Modal.onShift(modeS)
   modeS.zones.modal:show()
end

function Modal.onUnshift(modeS)
   modeS.zones.modal:hide()
end



return Modal


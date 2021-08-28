# Modal dialog

Raga for displaying a modal dialog. Uses a small z=2 zone to display.

```lua

local clone = assert(require 'core:table' . clone)
local a = require "anterm:anterm"
local RagaBase = require "helm:raga/base"
```
```lua
local Modal = clone(RagaBase, 2)
Modal.name = "modal"
Modal.prompt_char = " "
```
```lua
function Modal.close(maestro, value)
   maestro.agents.modal.model.value = value
   -- #todo shift back to the previous raga--modeS needs to maintain a stack
   maestro.modeS.shift_to = maestro.modeS.raga_default
end
```
### Keyboard input

```lua
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
```
### Keymap

```lua
local map = {
   ESC = "cancel",
   RETURN = "acceptDefault"
}
for i = 1, 26 do
   map[("abcdefghijklmnopqrstuvwxyz"):sub(i,i)] = "letterShortcut"
end
Modal.default_keymaps = { map }
```
### Modal.onShift, .onUnshift

```lua
function Modal.onShift(modeS)
   modeS.zones.modal:show()
end

function Modal.onUnshift(modeS)
   modeS.zones.modal:hide()
end
```
```lua
return Modal
```

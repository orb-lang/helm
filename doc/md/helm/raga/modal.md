# Modal dialog

Raga for displaying a modal dialog\. Uses a small z=2 zone to display\.

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


### Keymap

```lua
Modal.default_keymaps = {
   { source = "agents.modal", name = "keymap_actions" }
}
```


### Modal\.onShift, \.onUnshift

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
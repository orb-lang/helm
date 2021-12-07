# Edit base

Common functionality for ragas that accept keyboard input mostly by
directing it to the Txtbuf

```lua
local clone = assert(require "core:table" . clone)
local yield = assert(coroutine.yield)
local RagaBase = require "helm:helm/raga/base"
local Txtbuf = require "helm:buf/txtbuf"
```

```lua
local EditBase = clone(RagaBase, 2)
```


## Keymap

```lua
function EditBase.clearTxtbuf(maestro, event)
   EditBase.agentMessage("edit", "clear")
   EditBase.agentMessage("results", "clear")
   yield{ sendto = "hist", method = "toEnd" }
end

function EditBase.restartSession()
   yield{ method = "restart" }
end

EditBase.keymap_extra_commands = {
   ["C-l"] = "clearTxtbuf",
   ["C-r"] = "restartSession"
}

EditBase.default_keymaps = {
   { source = "agents.edit", name = "keymap_basic_editing" },
   { source = "modeS.raga", name = "keymap_extra_commands" }
}
```


## EditBase\.getCursorPosition\(modeS\)

Offset into the `command` zone, based on the Txtbuf's `cursor` property\.

```lua
function EditBase.getCursorPosition(modeS)
   return modeS.zones.command.bounds:origin() + modeS:agent'edit'.cursor - 1
end
```


```lua
return EditBase
```
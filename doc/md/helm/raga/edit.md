# Edit base

Common functionality for ragas that accept keyboard input mostly by
directing it to the Txtbuf

```lua
local clone = assert(require "core:table" . clone)
local insert = assert(table.insert)
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

local addall = assert(require "core:table" . addall)
EditBase.keymap_extra_commands = {
   ["C-l"] = "clearTxtbuf",
   ["C-r"] = "restartSession"
}
addall(EditBase.keymap_extra_commands, RagaBase.keymap_extra_commands)

EditBase.default_keymaps = clone(RagaBase.default_keymaps)
-- Allow extra commands to preempt basic-editing, e.g. a RETURN binding
-- should preempt insertion of a newline
insert(EditBase.default_keymaps,
   { source = "agents.edit", name = "keymap_basic_editing" })
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
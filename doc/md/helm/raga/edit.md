# Edit base

Common functionality for ragas that accept keyboard input mostly by
directing it to the Txtbuf

```lua
local table = core.table
local clone, insert = assert(table.clone), assert(table.insert)
local RagaBase = require "helm:helm/raga/base"
local Txtbuf = require "helm:buf/txtbuf"
```

```lua
local EditBase = clone(RagaBase, 2)
```


## Keymap

```lua
-- Allow extra commands to preempt basic-editing, e.g. a RETURN binding
-- should preempt insertion of a newline
EditBase.default_keymaps = clone(RagaBase.default_keymaps)
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

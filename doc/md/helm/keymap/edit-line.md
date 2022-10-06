# Edit\-line keymap

```lua
local Keymap = require "helm:keymap"
local parts = require "helm:keymap/parts"
```


```lua
return Keymap(
parts.set_targets("agents.run_review", {
   RETURN = "acceptInsertion",
   ESC = "cancelInsertEditing",
   ["C-q"] = "cancelInsertEditing"
}),
parts.set_targets("agents.suggest", {
   TAB = "activateCompletion",
   ["S-TAB"] = "activateCompletion"
}),
parts.basic_editing,
parts.global_commands)
```
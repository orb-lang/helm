# Edit\-title keymap

```lua
local Keymap = require "helm:keymap"
local parts = require "helm:keymap/parts"
```


```lua
return Keymap(
parts.set_targets("agents.session", {
   RETURN = "acceptTitleUpdate",
   TAB = "acceptTitleUpdate",
   ESC = "cancelTitleEditing",
   ["C-q"] = "acceptTitleUpdate"
}),
parts.basic_editing,
parts.global_commands)
```

# Complete keymap

```lua
local Keymap = require "helm:keymap"
local parts = require "helm:keymap/parts"
```


```lua
return Keymap({
   target = "agents.suggest",
   bindings = parts.list_selection
}, {
   target = "agents.suggest",
   bindings = {
      RETURN          = "acceptSelected",
      ESC             = "userCancel",
      LEFT            = "acceptAndFallthrough",
      PASTE           = "quitAndFallthrough",
      ["[CHARACTER]"] = { method = "acceptOnNonWordChar", n = 1 }
   }
}, {
   target = "modeS",
   bindings = parts.global_commands
})
```

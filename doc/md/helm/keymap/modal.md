# Modal keymap

```lua
local Keymap = require "helm:keymap"
local parts = require "helm:keymap/parts"
```


```lua
return Keymap({
   ESC = "cancel",
   RETURN = "acceptDefault",
   ["[CHARACTER]"] = { method = "letterShortcut", n = 1 }
},
parts.global_commands
)
```
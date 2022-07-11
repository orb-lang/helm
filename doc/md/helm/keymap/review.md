# Review keymap

```lua
local Keymap = require "helm:keymap"
local parts = require "helm:keymap/parts"
```


```lua
return Keymap({
   UP = "selectPreviousWrap",
   DOWN = "selectNextWrap",
   TAB = "toggleSelectedState",
   ["S-TAB"] = "reverseToggleSelectedState",
   a = { method = "setSelectedState", "accept"},
   r = { method = "setSelectedState", "reject"},
   i = { method = "setSelectedState", "ignore"},
   s = { method = "setSelectedState", "skip"},
   ["M-UP"] = "movePremiseUp",
   ["M-DOWN"] = "movePremiseDown",
   RETURN = "editSelectedTitle",
   ["C-q"] = "promptSaveChanges"
},
parts.set_targets("agents.session.results_agent", parts.cursor_scrolling),
parts.global_commands)
```
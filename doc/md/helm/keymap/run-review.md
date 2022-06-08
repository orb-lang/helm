# Run\-review \(interactive\-restart\) keymap

```lua
local Keymap = require "helm:keymap"
local parts = require "helm:keymap/parts"
```


```lua
return Keymap(parts.review_common,
{
   k = { method = "setSelectedState", "keep"},
   n = { method = "setSelectedState", "insert"},
   t = { method = "setSelectedState", "trash"},
   RETURN = "editInsertedLine",
   ["M-e"] = "evalAndResume"
},
parts.set_targets("agents.run_review.results_agent", parts.cursor_scrolling),
parts.global_commands)
```
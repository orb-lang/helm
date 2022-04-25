# Edit premise title

A simple, single\-purpose raga for editing the title of a session premise\.
This is ugly and really should be able to be generalized, but without a
proper raga stack it's the best we can do\.


```lua
local table = core.table
local clone, splice = assert(table.clone), assert(table.splice)
local EditBase = require "helm:helm/raga/edit"

local EditTitle = clone(EditBase, 2)
EditTitle.name = "edit_title"
EditTitle.prompt_char = "👉"
EditTitle.keymap = require "helm:keymap/edit-title"

return EditTitle
```
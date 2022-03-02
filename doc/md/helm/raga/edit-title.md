# Edit premise title

A simple, single\-purpose raga for editing the title of a session premise\.
This is ugly and really should be able to be generalized, but without a
proper raga stack it's the best we can do\.


```lua
local core_table = require "core:table"
local clone, splice = assert(core_table.clone), assert(core_table.splice)
local EditBase = require "helm:helm/raga/edit"

local EditTitle = clone(EditBase, 2)
EditTitle.name = "edit_title"
EditTitle.prompt_char = "👉"
```


## Keymap

```lua
EditTitle.default_keymaps = {
   { source = "agents.session", name = "keymap_edit_title" }
}
splice(EditTitle.default_keymaps, EditBase.default_keymaps)
```


```lua
return EditTitle
```
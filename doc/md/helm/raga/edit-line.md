# Edit premise line

Analagous to EditTitle but for inserted premises in interactive\-restart\.
Should be able to be generalized, but it turns out we need more than just
the raga stack to do this\.\.\.


```lua
local table = core.table
local clone, splice = assert(table.clone), assert(table.splice)
local EditBase = require "helm:helm/raga/edit"

local EditLine = clone(EditBase, 2)
EditLine.name = "edit_line"
EditLine.prompt_char = "👉"
EditLine.keymap = require "helm:keymap/edit-line"
EditLine.lex = require "helm:lex" . lua_thor
EditLine.target = "agents.edit"

return EditLine
```
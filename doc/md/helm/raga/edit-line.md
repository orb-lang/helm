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
```


### EditLine\.onCursorChanged\(\), EditLine\.onTxtbufChanged\(\)

\#todo

```lua
function EditLine.onCursorChanged()
   send { to = "agents.suggest", method = "update" }
   EditBase.onCursorChanged()
end

function EditLine.onTxtbufChanged()
   send { to = "agents.suggest", method = "update" }
   EditBase.onTxtbufChanged()
end
```


### EditLine\.onShift\(\)

We want to behave a bit more like Nerf than EditTitle does\-\-in particular, why
**not** have autocomplete?

\#todo
need a lot more functionality before we can do better\.

\#todo

```lua
function EditLine.onShift()
   send { to = "zones.suggest", method = "show" }
   -- #todo this messing directly with the Txtbuf is bad
   local txtbuf = send { to = "zones.command", field = "contents" }
   txtbuf.suggestions = send { to = "agents.suggest", method = "window" }
end
```


```lua
return EditLine
```
# Edit line

Analagous to EditTitle, but editing a line of Lua outside the normal REPL context,
e\.g\. the line of a round/premise during session review or interactive\-restart\.


```lua
local core = require "qor:core"
local clone = assert(core.table.clone)
local EditBase = require "helm:helm/raga/edit"

local EditLine = clone(EditBase, 2)
local send = EditLine.send

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
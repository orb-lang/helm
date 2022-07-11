# Search


```lua
local table = core.table
local clone, splice = assert(table.clone), assert(table.splice)
local EditBase = require "helm/raga/edit"
local Resbuf = require "helm:buf/resbuf"

local Search = clone(EditBase, 2)

Search.name = "search"
Search.prompt_char = "⁉️"
Search.keymap = require "helm:keymap/search"
```


### Search\.onTxtbufChanged\(\)

We need to update the search result whenever the contents of the Txtbuf change\.

```lua
function Search.onTxtbufChanged()
   send { to = "agents.search", method = "update" }
   EditBase.onTxtbufChanged()
end
```


### Search\.onShift

Set up Agent connections\-\-Txtbuf uses Historian for "suggestions", and that
same Window also drives the result zone\.

```lua
function Search.onShift()
   EditBase.onShift()
   send { to = "agents.search", method = "update" }
   -- #todo this messing directly with the Txtbuf is bad
   local txtbuf = send { to = "zones.command", field = "contents" }
   txtbuf.suggestions = send { to = "agents.search", method = "window" }
   send { method = "bindZone",
      "results", "search", Resbuf, { scrollable = true }}
end
```

```lua
return Search
```

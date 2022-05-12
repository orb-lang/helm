# Nerf mode


`nerf` is the default mode for the repl\.


-  \#Todo

  - [X]  All of the content for the first draft is in `modeselektor`, so
      let's transfer that\.

  - [?]  There should probably be a metatable for Mode objects\.


#### imports

```lua
local sub, gsub, rep = assert(string.sub),
                       assert(string.gsub),
                       assert(string.rep)
local table = core.table
local addall, clone, concat, insert, splice = assert(table.addall),
                                              assert(table.clone),
                                              assert(table.concat),
                                              assert(table.insert),
                                              assert(table.splice)
local s = require "status:status" ()
```


## Nerf

```lua

local EditBase = require "helm:helm/raga/edit"

local Nerf = clone(EditBase, 2)
Nerf.name = "nerf"
Nerf.prompt_char = "👉"
Nerf.keymap = require "helm:keymap/nerf"
Nerf.target = "agents.edit"
Nerf.lex = require "helm:lex" . lua_thor
```


### Nerf\.onCursorChanged\(\), Nerf\.onTxtbufChanged\(\)

Whenever the cursor moves or the Txtbuf contents change, need to
update the suggestions\.

```lua
function Nerf.onCursorChanged()
   send { to = "agents.suggest", method = "update" }
   EditBase.onCursorChanged()
end

function Nerf.onTxtbufChanged()
   send { to = "agents.suggest", method = "update" }
   EditBase.onTxtbufChanged()
end
```


### Nerf\.onShift

Set up Agent connections\-\-install the SuggestAgent's Window as the provider of
suggestions for the Txtbuf, and ResultsAgent to supply the content of the
results zone\.

```lua
local Resbuf = require "helm:buf/resbuf"
function Nerf.onShift()
   EditBase.onShift()
   -- #todo only if not already a Resbuf?
   send { method = "bindZone",
      "results", "results", Resbuf, { scrollable = true }}
   -- #todo this messing directly with the Txtbuf is bad
   local txtbuf = send { to = "zones.command", field = "contents" }
   txtbuf.suggestions = send { to = "agents.suggest", method = "window" }
end
```

```lua
return Nerf
```

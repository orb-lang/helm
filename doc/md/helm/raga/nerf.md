# Nerf mode


`nerf` is the default mode for the repl\.


-  \#Todo

  - [X]  All of the content for the first draft is in `modeselektor`, so
      let's transfer that\.

  - [?]  There should probably be a metatable for Mode objects\.


#### includes

```lua
local concat, insert = assert(table.concat), assert(table.insert)
local sub, gsub, rep = assert(string.sub),
                       assert(string.gsub),
                       assert(string.rep)
local yield = assert(coroutine.yield)
```


## Nerf

```lua
local clone    = import("core/table", "clone")
local EditBase = require "helm:helm/raga/edit"

local Nerf = clone(EditBase, 2)
Nerf.name = "nerf"
Nerf.prompt_char = "👉"
```

### Insertion

```lua

local function _insert(modeS, category, value)
   if modeS:agent'edit':contents() == "" then
      modeS:agent'results':clear()
      if value == "/" then
         Nerf.shiftMode("search")
         return
      end
      if value == "?" then
         modeS:openHelp()
         return
      end
   end
   modeS:agent'edit':insert(value)
end

Nerf.ASCII = _insert
Nerf.UTF8 = _insert

```

### NAV

```lua

local NAV = Nerf.NAV

function _eval(modeS)
   local line = modeS:agent'edit':contents()
   local success, results = modeS.eval(line)
   if not success and results == 'advance' then
      modeS:agent'edit':endOfText()
      modeS:agent'edit':nl()
   else
      modeS.hist:append(line, results, success)
      modeS.hist.cursor = modeS.hist.n + 1
      modeS:agent'results':update(results)
      modeS:agent'edit':clear()
   end
end

function NAV.RETURN(modeS, category, value)
   if modeS:agent'edit':shouldEvaluate() then
      _eval(modeS)
   else
      modeS:agent'edit':nl()
   end
end

function NAV.CTRL_RETURN(modeS, category, value)
   _eval(modeS)
end

function NAV.SHIFT_RETURN(modeS, category, value)
   modeS:agent'edit':nl()
end

-- Add aliases for terminals not in CSI u mode
Nerf.CTRL["^\\"] = NAV.CTRL_RETURN
NAV.ALT_RETURN = NAV.SHIFT_RETURN
```


### History navigation

```lua
function Nerf.historyBack()
   -- If we're at the end of the history (the user was typing a new
   -- expression), save it before moving
   if yield{ sendto = "hist", method = "atEnd" } then
      local linestash = Nerf.agentMessage("edit", "contents")
      yield{ sendto = "hist", method = "append", n = 1, linestash }
   end
   local prev_line, prev_result = modeS.hist:prev()
   Nerf.agentMessage("edit", "update", prev_line)
   Nerf.agentMessage("results", "update", prev_result)
end

function Nerf.historyForward()
   local new_line, next_result = yield{ sendto = "hist", method = "next" }
   if not new_line then
      local old_line = Nerf.agentMessage("edit", "contents")
      local added = yield{ sendto = "hist", method = "append", n = 1, old_line }
      if added then
         yield{ sendto = "hist", method = "toEnd" }
      end
   end
   Nerf.agentMessage("edit", "update", new_line)
   Nerf.agentMessage("results", "update", next_result)
end
```

### Keymaps

First a section of commands that need to react to certain keypresses under
certain circumstances, but often allow processing to continue\.

```lua
Nerf.default_keymaps = {
   { source = "agents.search", name = "keymap_try_activate" },
   { source = "agents.suggest", name = "keymap_try_activate" },
   { source = "agents.results", name = "keymap_reset" },
   { source = "agents.edit", name = "keymap_readline_nav" }
}
```

Then the inherited basic editing commands\.

```lua
for _, map in ipairs(EditBase.default_keymaps) do
   insert(Nerf.default_keymaps, map)
end
```

History navigation is a fallback from cursor movement\.

```lua
Nerf.keymap_history_navigation = {
   UP = "historyBack",
   DOWN = "historyForward"
}
insert(Nerf.default_keymaps,
       { source = "modeS.raga", name = "keymap_history_navigation"})
```

And results\-area scrolling binds several shortcuts that are already taken, so we need to make sure those others get there first\.

```lua
insert(Nerf.default_keymaps,
      { source = "agents.results", name = "keymap_scrolling" })
```


### ALT

```lua
local ALT = Nerf.ALT
```


#### M\-e

```lua
ALT ["M-e"] = function(modeS, category, value)
   local top = modeS.hist.n
   local cursor = modeS.hist.cursor
   for i = cursor, top do
      -- Discard the second return value from :index
      -- or it will confuse the Txtbuf constructor rather badly
      local line = modeS.hist:index(i)
      modeS:agent'edit':update(line)
      _eval(modeS)
   end
end
```

### Nerf\.onCursorChanged\(modeS\), Nerf\.onTxtbufChanged\(modeS\)

Whenever the cursor moves or the Txtbuf contents change, need to
update the suggestions\.

```lua
function Nerf.onCursorChanged(modeS)
   modeS:agent'suggest':update()
   EditBase.onCursorChanged(modeS)
end

function Nerf.onTxtbufChanged(modeS)
   modeS:agent'suggest':update()
   EditBase.onTxtbufChanged(modeS)
end
```


### Nerf\.onShift

Set up Agent connections\-\-install the SuggestAgent's Window as the provider of
suggestions for the Txtbuf, and ResultsAgent to supply the content of the
results zone\.

```lua
local Resbuf = require "helm:buf/resbuf"
function Nerf.onShift(modeS)
   EditBase.onShift(modeS)
   modeS:bindZone("results", "results", Resbuf, { scrollable = true })
   local txtbuf = modeS.zones.command.contents
   txtbuf.suggestions = modeS:agent'suggest':window()
end
```

```lua
return Nerf
```

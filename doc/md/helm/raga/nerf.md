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


### Nerf\.historianMessage\(method\_name, args\.\.\.\)

We communicate so much with the Historian that it seems worth a helper similar to \`agentMessage\`\.

```lua
function Nerf.historianMessage(method_name, ...)
   local msg = pack(...)
   msg.sendto = "hist"
   msg.method = method_name
   return yield(msg)
end
```

### Evaluation

```lua
function Nerf.eval()
   local line = Nerf.agentMessage("edit", "contents")
   local success, results = yield{ call = "eval", n = 1, line }
   if not success and results == 'advance' then
      Nerf.agentMessage("edit", "endOfText")
      return false -- Fall through to EditAgent nl binding
   else
      Nerf.historianMessage("append", line, results, success)
      Nerf.historianMessage("toEnd")
      Nerf.agentMessage("results", "update", results)
      Nerf.agentMessage("edit", "clear")
   end
end

function Nerf.conditionalEval()
   if Nerf.agentMessage("edit", "shouldEvaluate") then
      return Nerf.eval()
   else
      return false -- Fall through to EditAgent nl binding
   end
end

Nerf.keymap_evaluation = {
   RETURN = "conditionalEval",
   ["C-RETURN"] = "eval",
   ["S-RETURN"] = { sendto = "agents.edit", method = "nl" },
   -- Add aliases for terminals not in CSI u mode
   ["C-\\"] = "eval",
   ["M-RETURN"] = { sendto = "agents.edit", method = "nl" }
}
```


### History navigation

```lua
function Nerf.historyBack()
   -- If we're at the end of the history (the user was typing a new
   -- expression), save it before moving
   if Nerf.historianMessage("atEnd") then
      local linestash = Nerf.agentMessage("edit", "contents")
      Nerf.historianMessage("append", linestash)
   end
   local prev_line, prev_result = Nerf.historianMessage("prev")
   Nerf.agentMessage("edit", "update", prev_line)
   Nerf.agentMessage("results", "update", prev_result)
end

function Nerf.historyForward()
   local new_line, next_result = Nerf.historianMessage("next")
   if not new_line then
      local old_line = Nerf.agentMessage("edit", "contents")
      local added = Nerf.historianMessage("append", old_line)
      if added then
         Nerf.historianMessage("toEnd")
      end
   end
   Nerf.agentMessage("edit", "update", new_line)
   Nerf.agentMessage("results", "update", next_result)
end

Nerf.keymap_history_navigation = {
   UP = "historyBack",
   DOWN = "historyForward"
}
```


### Help screen

```lua
function Nerf.openHelpOnFirstKey()
   if Nerf.agentMessage("edit", "isEmpty") then
      yield{ method = "openHelp" }
      return true
   else
      return false
   end
end

Nerf.keymap_open_help = {
   ["?"] = "openHelpOnFirstKey"
}
```


### Keymaps

First a section of commands that need to react to certain keypresses under
certain circumstances, but often allow processing to continue\.

```lua
Nerf.default_keymaps = {
   { source = "agents.search", name = "keymap_try_activate" },
   { source = "agents.suggest", name = "keymap_try_activate" },
   { source = "modeS.raga", name = "keymap_open_help" },
   { source = "agents.results", name = "keymap_reset" },
```

Then some additional commands\-\-evaluation mainly, and we include
Readline\-compatible navigation\.

```lua
   { source = "modeS.raga", name = "keymap_evaluation" },
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
insert(Nerf.default_keymaps,
       { source = "modeS.raga", name = "keymap_history_navigation" })
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

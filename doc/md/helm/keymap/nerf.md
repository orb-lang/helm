# Nerf keymap

```lua
local Keymap = require "helm:keymap"
local parts = require "helm:keymap/parts"
```

```lua
return Keymap(
```

First a section of commands that need to react to certain keypresses under
certain circumstances, but often allow processing to continue\.

```lua
{
   bindings = {
      ["[CHARACTER]"] = { to = "agents.results", method = "clearOnFirstKey" },
      PASTE           = { to = "agents.results", method = "clearOnFirstKey" },
      TAB             = { to = "agents.suggest", method = "activateCompletion" },
      ["S-TAB"]       = { to = "agents.suggest", method = "activateCompletion" },
      ["/"]           = { to = "agents.search",  method = "activateOnFirstKey" },
      ["?"]           = { to = "modeS",          method = "openHelpOnFirstKey" }
   }
},
```

Evaluation needs to intercept RETURN prior to normal `nl` binding\.

```lua
{
   target = "modeS.raga",
   bindings = {
      RETURN = "conditionalEval",
      ["C-RETURN"] = "eval",
      ["S-RETURN"] = { to = "agents.edit", method = "nl" },
      ["M-e"] = "evalFromCursor",
      -- Add aliases for terminals not in CSI u mode
      ["C-\\"] = "eval",
      ["M-RETURN"] = { to = "agents.edit", method = "nl" }
   }
},
```

Readline\-style cursor movement commands for diehard Emacsians\.

In case RMS ever takes bridge for a spin\.\.\.

```lua
{
   target = "agents.edit",
   bindings = {
      ["C-b"] = "left",
      ["C-f"] = "right",
      ["C-n"] = "down",
      ["C-p"] = "up",
      -- #todo sneak this in here, it's got nothing
      -- to do with readline but whatever
      ["C-l"] = "clear"
   }
},
```

And the rest of the basic editing commands\.

```lua
{ target = "agents.edit", bindings = parts.basic_editing },
{ target = "modeS", bindings = parts.global_commands },
```

History navigation is a fallback from cursor movement\.

```lua
{
   target = "modeS.raga",
   bindings = {
      UP = "historyBack",
      DOWN = "historyForward"
   }
},
```

And results\-area scrolling binds several shortcuts that are already taken, so we need to make sure those others get there first\.

```lua
{ target = "agents.results", bindings = parts.cursor_scrolling }
```

```lua
)
```

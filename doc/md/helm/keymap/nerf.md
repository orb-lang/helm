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
   ["[CHARACTER]"] = { to = "agents.results", method = "clearOnFirstKey" },
   PASTE           = { to = "agents.results", method = "clearOnFirstKey" },
   TAB             = { to = "agents.suggest", method = "activateCompletion" },
   ["S-TAB"]       = { to = "agents.suggest", method = "activateCompletion" },
   ["/"]           = { to = "agents.search",  method = "activateOnFirstKey" },
   ["?"]           = { to = "modeS",          method = "openHelpOnFirstKey" }
},
```

Evaluation needs to intercept RETURN prior to normal `nl` binding\.

```lua
parts.set_targets("modeS", {
   RETURN = "conditionalEval",
   ["C-RETURN"] = "userEval",
   ["S-RETURN"] = { to = "", method = "nl" },
   ["M-e"] = "evalFromCursor",
   -- Add aliases for terminals not in CSI u mode
   ["C-\\"] = "userEval",
   ["M-RETURN"] = { to = "", method = "nl" }
}),
```

Readline\-style cursor movement commands for diehard Emacsians\.

In case RMS ever takes bridge for a spin\.\.\.

```lua
{
   ["C-b"] = "left",
   ["C-f"] = "right",
   ["C-n"] = "down",
   ["C-p"] = "up",
   -- #todo sneak this in here, it's got nothing
   -- to do with readline but whatever
   ["C-l"] = "clear"
},
```

And the rest of the basic editing commands\.

```lua
parts.basic_editing,
parts.global_commands,
```

History navigation is a fallback from cursor movement\.

```lua
parts.set_targets("modeS", {
   UP = "historyBack",
   DOWN = "historyForward"
}),
```

And results\-area scrolling binds several shortcuts that are already taken, so we need to make sure those others get there first\.

```lua
parts.set_targets("agents.results", parts.cursor_scrolling)
```

```lua
)
```
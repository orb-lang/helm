# Search keymap

```lua
local Keymap = require "helm:keymap"
local parts = require "helm:keymap/parts"
```

```lua
local action_bindings = {
   RETURN = "acceptSelected",
   ESC = "userCancel",
   BACKSPACE = "quitIfNoSearchTerm",
   DELETE = "quitIfNoSearchTerm"
}
for i = 1, 9 do
   action_bindings["M-" .. tostring(i)] = { method = "acceptFromNumberKey", n = 1 }
end
```

```lua
return Keymap(
parts.set_targets("agents.search", parts.list_selection),
parts.set_targets("agents.search", action_bindings),
parts.basic_editing,
parts.global_commands)
```
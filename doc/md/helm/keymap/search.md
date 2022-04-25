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
return Keymap({
   target = "agents.search",
   bindings = parts.list_selection
}, {
   target = "agents.search",
   bindings = action_bindings
}, {
   target = "agents.edit",
   bindings = parts.basic_editing
}, {
   target = "modeS",
   bindings = parts.global_commands
})
```
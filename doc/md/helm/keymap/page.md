# Page keymap

```lua
local Keymap = require "helm:keymap"
local parts = require "helm:keymap/parts"
```

```lua
local clone = assert(core.table.clone)
local our_bindings = clone(parts.cursor_scrolling)
for cmd, shortcuts in pairs{
   scrollDown     = { "RETURN", "e", "j", "C-n", "C-e", "C-j" },
   scrollUp       = { "S-RETURN", "y", "k", "C-y", "C-p", "C-l" },
   pageDown       = { " ", "f", "C-v", "C-f" },
   pageUp         = { "b", "C-b" },
   halfPageDown   = { "d", "C-d" },
   halfPageUp     = { "u", "C-u" },
   scrollToBottom = { "G", ">" },
   scrollToTop    = { "g", "<" },
   quit           = { "q", "ESC" }
} do
   for _, shortcut in ipairs(shortcuts) do
      our_bindings[shortcut] = cmd
   end
end
```

```lua
return Keymap(our_bindings, parts.global_commands)
```

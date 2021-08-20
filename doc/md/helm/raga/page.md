# Page

`page` is our equivalent of `less`, used for displaying help files and the like\.

```lua
local clone = import("core/table", "clone")
local RagaBase = require "helm:helm/raga/base"
```

```lua
local Page = clone(RagaBase, 2)

Page.name = "page"
Page.prompt_char = "❓"
```


## Keymap

The only command that routes to us is the exit/quit command, everything else
goes to the Rainbuf in the popup zone\.

\#todo
functions to ourself\. Ideally we'd find a way to specify the target directly,
but we can at least not write out all these functions by hand\.

```lua
function Page.quit(maestro, event)
   -- #todo should have a stack of ragas and switch back to the one
   -- we entered from, but this will do for now
   maestro.modeS:shiftMode(maestro.modeS.raga_default)
end

local map = {
   ESC = "quit",
   q = "quit"
}

for cmd, shortcuts in pairs{
   scrollDown     = { "SCROLL_DOWN", "DOWN", "S-DOWN", "RETURN",
                      "e", "j", "C-n", "C-e", "C-j" },
   scrollUp       = { "SCROLL_UP", "UP", "S-UP", "S-RETURN",
                      "y", "k", "C-y", "C-p", "C-l" },
   pageDown       = { "PAGE_DOWN", " ", "f", "C-v", "C-f" },
   pageUp         = { "PAGE_UP", "b", "C-b" },
   halfPageDown   = { "d", "C-d" },
   halfPageUp     = { "u", "C-u" },
   scrollToBottom = { "END", "G", ">" },
   scrollToTop    = { "HOME", "g", "<" }
} do
   Page[cmd] = function(maestro, event)
      local agent = maestro.agents.pager
      -- Most of these aren't mouse events, and most of the functions don't
      -- accept an argument anyway, but eh, an extra nil param is harmless
      -- #todo the keymap should actually be responsible for extracting the
      -- argument from the event, and the message should then be dispatched
      -- directly to the Agent
      agent[cmd](agent, event.num_lines)
   end
   for _, shortcut in ipairs(shortcuts) do
      map[shortcut] = cmd
   end
end
Page.default_keymaps = { map }
```


## Events

We basically ignore the majority of the zones and use the popup zone instead\.
Show and hide it automatically when we shift/unshift\.

```lua
function Page.onShift(modeS)
   modeS.zones.popup:show()
end
function Page.onUnshift(modeS)
   modeS.zones.popup:hide()
end
```

```lua
return Page
```
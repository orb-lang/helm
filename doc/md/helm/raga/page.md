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

local alias = require "helm/raga/aliaser" (Page)
```

## toZone\(fn\)

Returns a ModeS handler function that just calls the given method
of the popup zone\.

```lua
local function toZone(fn)
   return function(modeS, category, value)
      return modeS.zones.popup[fn](modeS.zones.popup)
   end
end
```

## Scrolling

```lua
alias{ toZone "scrollDown",
       NAV   = {"DOWN", "SHIFT_DOWN", "RETURN"},
       ASCII = {"e", "j"},
       CTRL  = {"^N", "^E", "^J"} }

alias{ toZone "scrollUp",
       NAV   = {"UP", "SHIFT_UP", "SHIFT_RETURN"},
       ASCII = {"y", "k"},
       CTRL  = {"^Y", "^P", "^K"} }

alias{ toZone "pageDown",
       ASCII = {" ", "f"},
       CTRL  = {"^V", "^F"} }
alias{ toZone "pageUp",
       ASCII = {"b"},
       CTRL  = {"^B"} }

alias{ toZone "halfPageDown",
       ASCII = {"d"},
       CTRL  = {"^D"} }
alias{ toZone "halfPageUp",
       ASCII = {"u"},
       CTRL  = {"^U"} }

alias{toZone "scrollToTop", ASCII = {"g", "<"}}
alias{toZone "scrollToBottom", ASCII = {"G", ">"}}
```

```lua

local function _quit(modeS)
   -- #todo should have a stack of ragas and switch back to the one
   -- we entered from, but this will do for now
   modeS.shift_to = "nerf"
end

alias{_quit, NAV = {"ESC"}, ASCII = {"q"} }
```

## MOUSE

```lua
function Page.MOUSE(modeS, category, value)
   if value.scrolling then
      if value.button == "MB0" then
         modeS.zones.popup:scrollUp()
      elseif value.button == "MB1" then
         modeS.zones.popup:scrollDown()
      end
   end
end
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
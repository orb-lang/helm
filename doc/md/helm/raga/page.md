# Page

``page`` is our equivalent of ``less``, used for displaying help files and the like.

```lua
local clone = import("core/table", "clone")
local RagaBase = require "helm:helm/raga/base"
```
```lua
local Page = clone(RagaBase, 2)

Page.name = "page"
Page.prompt_char = "❓"
```
## NAV

```lua
local NAV = Page.NAV

local function _scrollDown(modeS)
   modeS.zones.popup:scrollDown()
end
for _, key in ipairs{"DOWN", "SHIFT_DOWN", "RETURN"} do
   NAV[key] = _scrollDown
end

local function _scrollUp(modeS)
   modeS.zones.popup:scrollUp()
end
for _, key in ipairs{"UP", "SHIFT_UP", "SHIFT_RETURN"} do
   NAV[key] = _scrollUp
end

local function _quit(modeS)
   -- #todo should have a stack of ragas and switch back to the one
   -- we entered from, but this will do for now
   modeS.shift_to = "nerf"
end

NAV.ESC = _quit
```
## ASCII

We will eventually use lots of different ASCII characters as commands,
so we want a table, not a function.

```lua
local ASCII = Page.ASCII

ASCII["q"] = _quit
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

We basically ignore the majority of the zones and use the popup zone instead.
Show and hide it automatically when we shift/unshift.

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

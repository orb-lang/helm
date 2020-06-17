# Search


A light wrapper over `nerf`\.

```lua
local clone = import("core/table", "clone")
local EditBase = require "helm/raga/edit"
local Rainbuf = require "helm/rainbuf"

local Search = clone(EditBase, 2)

Search.name = "search"
Search.prompt_char = "⁉️"
```

## Input/updating search results

We need to update the search result whenever the contents of the Txtbuf change\.

```lua

function Search.onTxtbufChanged(modeS)
   local searchResult = modeS.hist:search(tostring(modeS.txtbuf))
   modeS:setResults(searchResult)
end

```

## Navigation

```lua

function Search.NAV.SHIFT_DOWN(modeS, category, value)
   local search_buf = modeS.hist.last_collection
   if not search_buf then return end
   local search_result = search_buf[1]
   if search_result:selectNext() then
      if search_result.selected_index >= search_buf.offset + modeS.zones.results:height() then
        search_buf:scrollDown()
      end
      modeS.zones.results:beTouched()
   end
end
```

```lua
function Search.NAV.SHIFT_UP(modeS, category, value)
   local search_buf = modeS.hist.last_collection
   if not search_buf then return end
   local search_result = search_buf[1]
   if search_result:selectPrevious() then
      if search_result.selected_index < search_buf.offset then
         search_buf:scrollUp()
      end
      modeS.zones.results:beTouched()
   end
end
```

\- \[ \]  \#Todo

  \- \[ \]  Add Search\.NAV\.SHIFT\_ALT\_\(UP|DOWN\), to move a page at a time\.
         Hook them to PgUp and PgDown while we're at it\.

  \- \[ \]  Add Search\.NAV\.HYPER\_UP and Search\.NAV\.HYPER\_DOWN to snap to the
         top and bottom\.  These are synonymous with Home and End\.

```lua
Search.NAV.UP = Search.NAV.SHIFT_UP
Search.NAV.DOWN = Search.NAV.SHIFT_DOWN

local function _modeShiftOnDeleteWhenEmpty(modeS, category, value)
   if tostring(modeS.txtbuf) == "" then
      modeS.shift_to = modeS.raga_default
      modeS:setResults("")
   else
      EditBase(modeS, category, value)
   end
end

Search.NAV.BACKSPACE = _modeShiftOnDeleteWhenEmpty
Search.NAV.DELETE    = _modeShiftOnDeleteWhenEmpty

```

### Accepting results

```lua

local function _acceptAtIndex(modeS, selected_index)
   local search_result = modeS.hist.last_collection[1]
   local txtbuf, result
   if #search_result > 0 then
      selected_index = selected_index or search_result.selected_index
      txtbuf, result = modeS.hist:index(search_result.cursors[selected_index])
   end
   modeS.shift_to = modeS.raga_default
   modeS:setTxtbuf(txtbuf or Txtbuf(), result)
   modeS:setResults(result)
end

function Search.NAV.RETURN(modeS, category, value)
   _acceptAtIndex(modeS)
end

local function _makeControl(num)
   return function(modeS, category, value)
      _acceptAtIndex(modeS, num)
   end
end

for i = 1, 9 do
   Search.ALT["M-" ..tostring(i)] = _makeControl(i)
end

```

### MOUSE

```lua
function Search.MOUSE(modeS, category, value)
   if value.scrolling then
      if value.button == "MB0" then
         modeS.raga.NAV.SHIFT_DOWN(modeS, category, value)
      elseif value.button == "MB1" then
         modeS.raga.NAV.SHIFT_UP(modeS, category, value)
      end
   end
end
```

```lua
return Search
```
# Search


```lua
local clone = import("core/table", "clone")
local EditBase = require "helm/raga/edit"
local Txtbuf = require "helm:buf/txtbuf"
local Resbuf = require "helm:buf/resbuf"

local Search = clone(EditBase, 2)

Search.name = "search"
Search.prompt_char = "⁉️"
```


## Navigation

```lua
local NAV = Search.NAV

function NAV.SHIFT_DOWN(modeS, category, value)
   modeS:agent'search':selectNext()
end
```

```lua
function NAV.SHIFT_UP(modeS, category, value)
   modeS:agent'search':selectPrevious()
end
```

```lua
function NAV.ESC(modeS, category, value)
   local search_result = modeS:agent'search'.last_collection
   -- No results or nothing is selected, exit search mode
   if not search_result or search_result.selected_index == 0 then
      modeS.shift_to = modeS.raga_default
   -- If something *is* selected, deselect it first
   else
      modeS:agent'search':selectNone()
   end
end
```


- [ ]  \#Todo

  - [ ]  Add NAV\.SHIFT\_ALT\_\(UP|DOWN\), to move a page at a time\.
      Hook them to PgUp and PgDown while we're at it\.

  - [ ]  Add NAV\.HOME and NAV\.END to snap to the
      top and bottom\.

```lua
NAV.DOWN      = NAV.SHIFT_DOWN
NAV.TAB       = NAV.SHIFT_DOWN
NAV.UP        = NAV.SHIFT_UP
NAV.SHIFT_TAB = NAV.SHIFT_UP

local function _modeShiftOnDeleteWhenEmpty(modeS, category, value)
   if modeS:agent'edit':contents() == "" then
      modeS.shift_to = modeS.raga_default
   else
      EditBase(modeS, category, value)
   end
end

NAV.BACKSPACE = _modeShiftOnDeleteWhenEmpty
NAV.DELETE    = _modeShiftOnDeleteWhenEmpty

```

### Accepting results

```lua

local function _acceptAtIndex(modeS, selected_index)
   local search_result = modeS:agent'search'.last_collection
   local line, result
   if #search_result > 0 then
      selected_index = selected_index or search_result.selected_index
      if selected_index == 0 then selected_index = 1 end
      line, result = modeS.hist:index(search_result.cursors[selected_index])
   end
   modeS.shift_to = modeS.raga_default
   modeS:agent'edit':update(line)
   modeS:setResults(result)
end

function NAV.RETURN(modeS, category, value)
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


## Search\.onTxtbufChanged\(modeS\)

We need to update the search result whenever the contents of the Txtbuf change\.

```lua
function Search.onTxtbufChanged(modeS)
   modeS:agent'search':update(modeS)
end
```


### Search\.onShift

Set up Agent connections\-\-Txtbuf uses Historian for "suggestions", and that
same Window also drives the result zone\.

```lua
function Search.onShift(modeS)
   EditBase.onShift(modeS)
   modeS:agent'search':update(modeS)
   modeS.zones.command.contents.suggestions = modeS:agent'search':window()
   modeS:bindZone("results", "search", Resbuf, { scrollable = true })
end
```

```lua
return Search
```

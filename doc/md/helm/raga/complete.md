# Complete

Handles choosing and accepting a suggestion from `suggest`\.

```lua
local clone = import("core/table", "clone")
local EditBase = require "helm/raga/edit"

local Complete = clone(EditBase, 2)

Complete.name = "complete"
Complete.prompt_char = "💬"
```

## Inserts

```lua

local function _quit(modeS)
   -- #todo restore last-used raga instead of always returning to default
   modeS.shift_to = modeS.raga_default
end

local function _accept(modeS)
   if modeS.suggest.active_suggestions then
      modeS.suggest:accept(modeS.txtbuf)
   else
      modeS.action_complete = false
   end
   _quit(modeS)
end

function Complete.PASTE(modeS, category, value)
   _quit(modeS)
   modeS.action_complete = false
end

```

```lua
local find = assert(string.find)
local function _insert(modeS, category, value)
   -- Non-symbol character accepts the completion
   -- #todo should be consistent with lex.orb definition
   if find(value, "[^a-zA-Z0-9_]") then
      _accept(modeS, category, value)
      modeS.action_complete = false
   else
      EditBase(modeS, category, value)
   end
end

Complete.ASCII = _insert
Complete.UTF8 = _insert
```

## NAV

```lua
local NAV = Complete.NAV

local function _scrollAfter(modeS, func_name)
   local suggestions = modeS.suggest.active_suggestions
   local zone = modeS.zones.suggest
   if suggestions then
      suggestions[func_name](suggestions)
      zone:ensureVisible(suggestions.selected_index)
      zone:beTouched()
   end
   -- Command zone needs re-render too
   modeS.zones.command:beTouched()
end

function NAV.TAB(modeS, category, value)
   _scrollAfter(modeS, "selectNextWrap")
end
NAV.DOWN = NAV.TAB
NAV.SHIFT_DOWN = NAV.TAB

function NAV.SHIFT_TAB(modeS, category, value)
   _scrollAfter(modeS, "selectPreviousWrap")
end
NAV.UP = NAV.SHIFT_TAB
NAV.SHIFT_UP = NAV.SHIFT_TAB

NAV.ESC = _quit
NAV.RETURN = _accept

function NAV.LEFT(modeS, category, value)
   _accept(modeS, category, value)
   modeS.action_complete = false
end
```


### Complete\.onTxtbufChanged\(modeS\)

Update the suggestion list when the user types something\. Note that this won't
be hit after a paste, or if the character inserted caused an accept, because
we will have already shifted ragas\.

```lua
function Complete.onTxtbufChanged(modeS)
   modeS.suggest:update(modeS.txtbuf, modeS.zones.suggest)
   if not modeS.suggest.active_suggestions then
      _quit(modeS)
   end
   EditBase.onTxtbufChanged(modeS)
end
```


### Complete\.onCursorChanged\(modeS\)

Any cursor movement drops us out of Complete mode\. Note that
onCursorChanged and onTxtbufChanged are mutually exclusive\-\-this does not
fire on a simple insert\.

```lua
function Complete.onCursorChanged(modeS)
   _quit(modeS)
   EditBase.onCursorChanged(modeS)
end
```


### Complete\.getCursorPosition\(modeS\)

If a suggestion is selected, adjust the cursor position
to the end of the suggestion\.

```lua
local Point = require "anterm:point"
function Complete.getCursorPosition(modeS)
   local point = EditBase.getCursorPosition(modeS)
   local suggestion = modeS.suggest:selectedSuggestion()
   if suggestion then
      for _, tok in ipairs(modeS.txtbuf:tokens()) do
         if tok.cursor_offset then
            point = point + Point(0, #suggestion - tok.cursor_offset)
            break
         end
      end
   end
   return point
end
```


### Complete\.onShift

Select the first item in the list when entering complete mode\.

```lua
function Complete.onShift(modeS)
   _scrollAfter(modeS, "selectFirst")
end
```


### Complete\.onUnshift

Deselect and prod the Txtbuf on exit\.

```lua
function Complete.onUnshift(modeS)
   _scrollAfter(modeS, "selectNone")
end
```

```lua
return Complete
```

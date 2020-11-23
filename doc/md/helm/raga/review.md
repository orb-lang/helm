# Session review

Raga for reviewing a previously\-saved session\.

```lua
local clone = assert(require "core:table" . clone)
local RagaBase = require "helm:raga/base"
local Txtbuf = require "helm:txtbuf"
local Sessionbuf = require "helm:sessionbuf"
```

```lua
local Review = clone(RagaBase, 2)
Review.name = "review"
Review.prompt_char = "💬"
```


### \_toSessionbuf\(fn\)


### NAV

```lua
local function _toSessionbuf(fn)
   return function(modeS, category, value)
      local buf = modeS.zones.results.contents
      modeS.zones.results:beTouched()
      return buf[fn](buf)
   end
end

local function _selectUsing(fn)
   return function(modeS, category, value)
      local buf = modeS.zones.results.contents
      buf[fn](buf)
      modeS.txtbuf:replace(buf:selectedPremise().title)
      modeS.zones.results:beTouched()
   end
end

local NAV = Review.NAV

NAV.UP   = _selectUsing "selectPrevious"
NAV.DOWN = _selectUsing "selectNext"

NAV.SHIFT_UP   = _toSessionbuf "scrollResultsUp"
NAV.SHIFT_DOWN = _toSessionbuf "scrollResultsDown"

NAV.TAB = _toSessionbuf "toggleSelectedState"

function NAV.RETURN(modeS, category, value)
   modeS.shift_to = "edit_title"
end
```


### Quit handler

We intercept ^Q to prompt the user whether to save the session before quitting\.

```lua
Review.CTRL["^Q"] = function(modeS, category, value)
   modeS:showModal('Save changes to the session "'
      .. modeS.hist.session.session_title .. '"?',
      "yes_no_cancel")
end
```


### MOUSE

We use the mouse wheel to scroll the results area\. Ideally it would be nice
to choose between the results area and the entire session display based on
cursor position, but that'll have to wait for more general focus\-tracking\.

```lua
function Review.MOUSE(modeS, category, value)
   if value.scrolling then
      if value.button == "MB0" then
         NAV.SHIFT_UP(modeS, category, value)
      elseif value.button == "MB1" then
         NAV.SHIFT_DOWN(modeS, category, value)
      end
   end
end
```


### Review\.onShift\(modeS\)

We use the results area for displaying the lines and results
of the session in a Sessionbuf\-\-if one is not already there,
set it up\.
We use a modal to prompt the user to save on quit, so if a modal
answer is set, this is what it is about\. This is rather ugly, but
requires a whole bunch of refactoring of Ragas and Zones to improve\.

```lua
function Review.onShift(modeS)
   local modal_answer = modeS:modalAnswer()
   if modal_answer then
      if modal_answer == "yes" then
         modeS.hist.session:save()
         modeS:quit()
      elseif modal_answer == "no" then
         modeS:quit()
      end -- Do nothing on cancel
      return
   end
   local contents = modeS.zones.results.contents
   if not contents or contents.idEst ~= Sessionbuf then
      local buf = Sessionbuf(modeS.hist.session, { scrollable = true })
      modeS.zones.results:replace(buf)
      modeS.txtbuf:replace(buf:selectedPremise().title)
   end
end
```

```lua
return Review
```
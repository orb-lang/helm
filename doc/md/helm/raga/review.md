# Session review

Raga for reviewing a previously\-saved session\.

```lua
local clone = assert(require "core:table" . clone)
local RagaBase = require "helm:raga/base"
local Txtbuf = require "helm:buf/txtbuf"
local Sessionbuf = require "helm:buf/sessionbuf"
```

```lua
local Review = clone(RagaBase, 2)
Review.name = "review"
Review.prompt_char = "💬"
```


### \_selectUsing\(fn\)

SessionAgent can't yet handle **quite** all of the stuff that needs to happen
when we change selection\-\-specifically updating the title in the EditAgent\-\-so
we need a simple wrapper\.

```lua
local function _toSessionAgent(fn)
   return function(modeS, category, value)
      local agent = modeS:agent'session'
      return agent[fn](agent)
   end
end

local function _selectUsing(fn)
   return function(modeS, category, value)
      local agent = modeS:agent'session'
      local answer = agent[fn](agent)
      local premise = agent:selectedPremise()
      modeS:agent'edit':update(premise and premise.title)
      return answer
   end
end
```


### NAV

```lua
local NAV = Review.NAV

NAV.UP   = _selectUsing "selectPreviousWrap"
NAV.DOWN = _selectUsing "selectNextWrap"

NAV.SHIFT_UP   = _toSessionAgent "scrollResultsUp"
NAV.SHIFT_DOWN = _toSessionAgent "scrollResultsDown"

NAV.TAB       = _toSessionAgent "toggleSelectedState"
NAV.SHIFT_TAB = _toSessionAgent "reverseToggleSelectedState"

function NAV.RETURN(modeS, category, value)
   if modeS:agent'session'.selected_index ~= 0 then
      modeS.shift_to = "edit_title"
   end
end

NAV.ALT_UP   = _toSessionAgent "movePremiseUp"
NAV.ALT_DOWN = _toSessionAgent "movePremiseDown"
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
   -- Hide the suggestion column so the review interface can occupy
   -- the full width of the terminal.
   -- #todo once we are able to switch between REPLing and review
   -- on the fly, we'll need to put this back as appropriate, but I
   -- think that'll come naturally once we have a raga stack.
   modeS.zones.suggest:hide()

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

   modeS:bindZone("results", "session", Sessionbuf, {scrollable = true})
   local premise = modeS:agent'session':selectedPremise()
   modeS:agent'edit':update(premise and premise.title)
end
```

```lua
return Review
```





local clone = assert(require "core:table" . clone)
local RagaBase = require "helm:raga/base"
local Txtbuf = require "helm:buf/txtbuf"
local Sessionbuf = require "helm:buf/sessionbuf"



local Review = clone(RagaBase, 2)
Review.name = "review"
Review.prompt_char = "💬"









local function _toSessionAgent(fn)
   return function(modeS, category, value)
      local agent = modeS:agent'session'
      return agent[fn](agent)
   end
end

local function _toSessionbuf(fn)
   return function(modeS, category, value)
      local buf = modeS.zones.results.contents
      return buf[fn](buf)
   end
end

local function _onSelectionChanged(modeS)
   local premise = modeS:agent'session':selectedPremise()
   modeS:agent'edit':update(premise and premise.title)
   local buf = modeS.zones.results.contents
   local start_index = buf:positionOfSelected()
   local end_index = start_index + buf:rowsForSelectedResult() + 3
   buf:ensureVisible(start_index, end_index)
end

local function _selectUsing(fn)
   return function(modeS, category, value)
      local agent = modeS:agent'session'
      local answer = agent[fn](agent)
      _onSelectionChanged(modeS)
      return answer
   end
end






local NAV = Review.NAV

NAV.UP   = _selectUsing "selectPreviousWrap"
NAV.DOWN = _selectUsing "selectNextWrap"

NAV.SHIFT_UP   = _toSessionbuf "scrollResultsUp"
NAV.SHIFT_DOWN = _toSessionbuf "scrollResultsDown"

NAV.TAB       = _toSessionAgent "toggleSelectedState"
NAV.SHIFT_TAB = _toSessionAgent "reverseToggleSelectedState"

function NAV.RETURN(modeS, category, value)
   if modeS:agent'session'.selected_index ~= 0 then
      modeS.shift_to = "edit_title"
   end
end

NAV.ALT_UP   = _toSessionAgent "movePremiseUp"
NAV.ALT_DOWN = _toSessionAgent "movePremiseDown"








Review.CTRL["^Q"] = function(modeS, category, value)
   modeS:showModal('Save changes to the session "'
      .. modeS.hist.session.session_title .. '"?',
      "yes_no_cancel")
end










function Review.MOUSE(modeS, category, value)
   if value.scrolling then
      if value.button == "MB0" then
         NAV.SHIFT_UP(modeS, category, value)
      elseif value.button == "MB1" then
         NAV.SHIFT_DOWN(modeS, category, value)
      end
   end
end














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



return Review


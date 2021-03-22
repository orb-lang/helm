




local clone = assert(require "core:table" . clone)
local RagaBase = require "helm:raga/base"
local Txtbuf = require "helm:txtbuf"
local Sessionbuf = require "helm:sessionbuf"



local Review = clone(RagaBase, 2)
Review.name = "review"
Review.prompt_char = "💬"









local function _toSessionbuf(fn)
   return function(modeS, category, value)
      local buf = modeS.zones.results.contents
      local answer = buf[fn](buf)
      modeS.zones.results:beTouched()
      return answer
   end
end

local function _onSelectionChanged(modeS)
   local zone = modeS.zones.results
   local buf = zone.contents
   modeS.txtbuf:replace(buf:selectedPremise().title)
   local start_index = buf:positionOfSelected()
   local end_index = start_index + buf:rowsForSelectedResult() + 3
   modeS.zones.results:ensureVisible(start_index, end_index)
   modeS.zones.results:beTouched()
end

local function _selectUsing(fn)
   return function(modeS, category, value)
      local buf = modeS.zones.results.contents
      local answer = buf[fn](buf)
      _onSelectionChanged(modeS)
      return answer
   end
end






local NAV = Review.NAV

NAV.UP   = _selectUsing "selectPreviousWrap"
NAV.DOWN = _selectUsing "selectNextWrap"

NAV.SHIFT_UP   = _toSessionbuf "scrollResultsUp"
NAV.SHIFT_DOWN = _toSessionbuf "scrollResultsDown"

NAV.TAB = _toSessionbuf "toggleSelectedState"
NAV.SHIFT_TAB = _toSessionbuf "toggleSelectedState"

function NAV.RETURN(modeS, category, value)
   if modeS.zones.results.contents.selected_index ~= 0 then
      modeS.shift_to = "edit_title"
   end
end

NAV.ALT_UP   = _toSessionbuf "movePremiseUp"
NAV.ALT_DOWN = _toSessionbuf "movePremiseDown"








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

   local contents = modeS.zones.results.contents
   if not contents or contents.idEst ~= Sessionbuf then
      local buf = Sessionbuf(modeS.hist.session, { scrollable = true })
      modeS.zones.results:replace(buf)
      local premise = buf:selectedPremise()
      modeS.txtbuf:replace(premise and premise.title or "")
   else
      _onSelectionChanged(modeS)
   end
end



return Review


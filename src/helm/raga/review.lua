




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



return Review


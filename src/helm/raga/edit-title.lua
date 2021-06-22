







local clone    = import("core/table", "clone")
local EditBase = require "helm:helm/raga/edit"

local EditTitle = clone(EditBase, 2)
EditTitle.name = "edit_title"
EditTitle.prompt_char = "👉"









local function _getSelectedPremise(modeS)
   return modeS.zones.results.contents:selectedPremise()
end






local function _accept(modeS)
   local sessionbuf = modeS.zones.results.contents
   sessionbuf:selectedPremise().title = modeS.maestro.agents.edit:contents()
   sessionbuf:selectNextWrap()
   modeS.shift_to = "review"
end

EditTitle.NAV.RETURN = _accept
EditTitle.NAV.TAB = _accept

function EditTitle.NAV.ESC(modeS, category, value)
   modeS.maestro.agents.edit:update(_getSelectedPremise(modeS).title)
   modeS.shift_to = "review"
end









EditTitle.CTRL["^Q"] = function(modeS, category, value)
   _accept(modeS)
   modeS.action_complete = false
end






EditTitle.CTRL["^R"] = nil




return EditTitle


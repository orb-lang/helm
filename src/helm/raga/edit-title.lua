







local clone    = import("core/table", "clone")
local EditBase = require "helm:helm/raga/edit"

local EditTitle = clone(EditBase, 2)
EditTitle.name = "edit_title"
EditTitle.prompt_char = "👉"






local function _accept(modeS)
   local agents = modeS.maestro.agents
   agents.session:selectedPremise().title = agents.edit:contents()
   agents.session:selectNextWrap()
   modeS.shift_to = "review"
end

EditTitle.NAV.RETURN = _accept
EditTitle.NAV.TAB = _accept

function EditTitle.NAV.ESC(modeS, category, value)
   local agents = modeS.maestro.agents
   agents.edit:update(agents.session:selectedPremise().title)
   modeS.shift_to = "review"
end









EditTitle.CTRL["^Q"] = function(modeS, category, value)
   _accept(modeS)
   modeS.action_complete = false
end








EditTitle.CTRL["^R"] = nil




return EditTitle










local clone    = import("core/table", "clone")
local EditBase = require "helm:helm/raga/edit"

local EditTitle = clone(EditBase, 2)
EditTitle.name = "edit_title"
EditTitle.prompt_char = "👉"








function EditTitle.ASCII(modeS, category, value)
   modeS.txtbuf:insert(value)
end
EditTitle.UTF8 = EditTitle.ASCII

function EditTitle.PASTE(modeS, category, value)
   modeS.txtbuf:paste(value)
end









local function _getSelectedPremise(modeS)
   return modeS.zones.results.contents:selectedPremise()
end






function EditTitle.NAV.RETURN(modeS, category, value)
   _getSelectedPremise(modeS).title = tostring(modeS.txtbuf)
   modeS.shift_to = "review"
end

function EditTitle.NAV.ESC(modeS, category, value)
   modeS.txtbuf:replace(_getSelectedPremise(modeS).title)
   modeS.shift_to = "review"
end








EditTitle.CTRL["^R"] = nil




return EditTitle


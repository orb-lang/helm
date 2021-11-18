







local clone    = import("core/table", "clone")
local EditBase = require "helm:helm/raga/edit"

local EditTitle = clone(EditBase, 2)
EditTitle.name = "edit_title"
EditTitle.prompt_char = "👉"






function EditTitle.accept()
   local title = EditTitle.agentMessage("edit", "contents")
   EditTitle.agentMessage("session", "titleUpdated", title)
   EditTitle.quit()
end

function EditTitle.quit()
   EditTitle.shiftMode("review")
end






EditTitle.keymap_extra_commands = {
   RETURN = "accept",
   TAB = "accept",
   ESC = "cancel"
}
for key, msg in pairs(EditBase.keymap_extra_commands) do
   EditTitle.keymap_extra_commands[key] = msg
end










EditTitle.CTRL["^Q"] = function(modeS, category, value)
   _accept(modeS)
   modeS.action_complete = false
end








EditTitle.CTRL["^R"] = nil




return EditTitle


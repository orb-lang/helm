







local core_table = require "core:table"
local addall, clone = assert(core_table.addall), assert(core_table.clone)
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
   ESC = "quit"
}
addall(EditTitle.keymap_extra_commands, EditBase.keymap_extra_commands)








EditTitle.keymap_extra_commands["C-r"] = nil









local yield = assert(coroutine.yield)
function EditTitle.quitHelm()
   EditTitle.accept()
   yield{ method = "tryAgain" }
end




return EditTitle


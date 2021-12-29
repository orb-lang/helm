







local core_table = require "core:table"
local addall, clone = assert(core_table.addall), assert(core_table.clone)
local EditBase = require "helm:helm/raga/edit"

local EditTitle = clone(EditBase, 2)
EditTitle.name = "edit_title"
EditTitle.prompt_char = "👉"






function EditTitle.accept()
   local title = send { sendto = "agents.edit", method = "contents" }
   send { sendto = "agents.session", method = "titleUpdated", title }
   EditTitle.quit()
end

function EditTitle.quit()
   send { method = "shiftMode", "review" }
end

EditTitle.keymap_extra_commands = {
   RETURN = "accept",
   TAB = "accept",
   ESC = "quit"
}
addall(EditTitle.keymap_extra_commands, EditBase.keymap_extra_commands)








EditTitle.keymap_extra_commands["C-r"] = nil









function EditTitle.quitHelm()
   EditTitle.accept()
   send { method = "tryAgain" }
end




return EditTitle


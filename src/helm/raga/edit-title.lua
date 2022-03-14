







local table = core.table
local clone, splice = assert(table.clone), assert(table.splice)
local EditBase = require "helm:helm/raga/edit"

local EditTitle = clone(EditBase, 2)
EditTitle.name = "edit_title"
EditTitle.prompt_char = "👉"






EditTitle.default_keymaps = {
   { source = "agents.session", name = "keymap_edit_title" }
}
splice(EditTitle.default_keymaps, EditBase.default_keymaps)




return EditTitle


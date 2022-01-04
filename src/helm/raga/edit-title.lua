







local core_table = require "core:table"
local clone, splice = assert(core_table.clone), assert(core_table.splice)
local EditBase = require "helm:helm/raga/edit"

local EditTitle = clone(EditBase, 2)
EditTitle.name = "edit_title"
EditTitle.prompt_char = "👉"






EditTitle.default_keymaps = {
   { source = "agents.session", name = "keymap_title_editing" }
}
splice(EditTitle.default_keymaps, EditBase.default_keymaps)




return EditTitle


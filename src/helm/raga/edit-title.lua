







local table = core.table
local clone, splice = assert(table.clone), assert(table.splice)
local EditBase = require "helm:helm/raga/edit"

local EditTitle = clone(EditBase, 2)
EditTitle.name = "edit_title"
EditTitle.prompt_char = "👉"
EditTitle.keymap = require "helm:keymap/edit-title"

return EditTitle


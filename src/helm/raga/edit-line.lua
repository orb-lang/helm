







local table = core.table
local clone, splice = assert(table.clone), assert(table.splice)
local EditBase = require "helm:helm/raga/edit"

local EditLine = clone(EditBase, 2)
EditLine.name = "edit_line"
EditLine.prompt_char = "👉"
EditLine.keymap = require "helm:keymap/edit-line"
EditLine.target = "agents.edit"

return EditLine


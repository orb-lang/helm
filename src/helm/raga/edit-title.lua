







local core = require "qor:core"
local clone = assert(core.table.clone)
local EditBase = require "helm:helm/raga/edit"

local EditTitle = clone(EditBase, 2)
EditTitle.name = "edit_title"
EditTitle.prompt_char = "👉"
EditTitle.keymap = require "helm:keymap/edit-title"

return EditTitle


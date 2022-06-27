







local table = core.table
local clone, splice = assert(table.clone), assert(table.splice)
local EditBase = require "helm:helm/raga/edit"

local EditLine = clone(EditBase, 2)
EditLine.name = "edit_line"
EditLine.prompt_char = "👉"
EditLine.keymap = require "helm:keymap/edit-line"
EditLine.lex = require "helm:lex" . lua_thor
EditLine.target = "agents.edit"








function EditLine.onCursorChanged()
   send { to = "agents.suggest", method = "update" }
   EditBase.onCursorChanged()
end

function EditLine.onTxtbufChanged()
   send { to = "agents.suggest", method = "update" }
   EditBase.onTxtbufChanged()
end














function EditLine.onShift()
   send { to = "zones.suggest", method = "show" }
   -- #todo this messing directly with the Txtbuf is bad
   local txtbuf = send { to = "zones.command", field = "contents" }
   txtbuf.suggestions = send { to = "agents.suggest", method = "window" }
end




return EditLine


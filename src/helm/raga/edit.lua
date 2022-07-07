





local table = core.table
local clone, insert = assert(table.clone), assert(table.insert)
local RagaBase = require "helm:helm/raga/base"
local Txtbuf = require "helm:buf/txtbuf"



local EditBase = clone(RagaBase, 2)
EditBase.target = "agents.edit"








function EditBase.getCursorPosition()
   local command_origin = send { to = "zones.command.bounds", method = "origin" }
   local edit_cursor = send { to = "agents.edit", field = "cursor" }
   return command_origin + edit_cursor - 1
end




return EditBase


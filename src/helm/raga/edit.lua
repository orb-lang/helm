





local core = require "qor:core"
local clone = assert(core.table.clone)
local RagaBase = require "helm:helm/raga/base"



local EditBase = clone(RagaBase, 2)
EditBase.target = "agents.edit"








function EditBase.getCursorPosition()
   local command_origin = send { to = "zones.command.bounds", method = "origin" }
   local edit_cursor = send { to = "agents.edit", field = "cursor" }
   return command_origin + edit_cursor - 1
end




return EditBase








local table = core.table
local clone, insert = assert(table.clone), assert(table.insert)
local RagaBase = require "helm:helm/raga/base"
local Txtbuf = require "helm:buf/txtbuf"



local EditBase = clone(RagaBase, 2)








function EditBase.getCursorPosition(modeS)
   return modeS.zones.command.bounds:origin() + modeS:agent'edit'.cursor - 1
end




return EditBase


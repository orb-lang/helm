





local table = core.table
local clone, insert = assert(table.clone), assert(table.insert)
local RagaBase = require "helm:helm/raga/base"
local Txtbuf = require "helm:buf/txtbuf"



local EditBase = clone(RagaBase, 2)






-- Allow extra commands to preempt basic-editing, e.g. a RETURN binding
-- should preempt insertion of a newline
EditBase.default_keymaps = clone(RagaBase.default_keymaps)
insert(EditBase.default_keymaps,
   { source = "agents.edit", name = "keymap_basic_editing" })








function EditBase.getCursorPosition(modeS)
   return modeS.zones.command.bounds:origin() + modeS:agent'edit'.cursor - 1
end




return EditBase


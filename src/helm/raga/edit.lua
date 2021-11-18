





local clone = assert(require "core:table" . clone)
local yield = assert(coroutine.yield)
local RagaBase = require "helm:helm/raga/base"
local Txtbuf = require "helm:buf/txtbuf"



local EditBase = clone(RagaBase, 2)






function EditBase.clearTxtbuf(maestro, event)
   EditBase.agentMessage("edit", "clear")
   EditBase.agentMessage("results", "clear")
   yield{ sendto = "hist", method = "toEnd" }
end

function EditBase.restartSession()
   yield{ method = "restart" }
end

EditBase.keymap_extra_commands = {
   ["C-l"] = "clearTxtbuf",
   ["C-r"] = "restartSession"
}

EditBase.default_keymaps = {
   { source = "agents.edit", name = "keymap_basic_editing" },
   { source = "modeS.raga", name = "keymap_extra_commands" }
}







local function _insert(modeS, category, value)
   if modeS:agent'edit':contents() == "" then
      modeS:agent'results':clear()
   end
   modeS:agent'edit':insert(value)
end

EditBase.ASCII = _insert
EditBase.UTF8 = _insert








function EditBase.getCursorPosition(modeS)
   return modeS.zones.command.bounds:origin() + modeS:agent'edit'.cursor - 1
end




return EditBase


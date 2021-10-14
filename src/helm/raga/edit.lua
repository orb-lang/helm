





local addall, clone = import("core/table", "addall", "clone")
local RagaBase = require "helm:helm/raga/base"
local Txtbuf = require "helm:buf/txtbuf"



local EditBase = clone(RagaBase, 2)






function EditBase.clearTxtbuf(maestro, event)
   maestro.agents.edit:clear()
   maestro.agents.results:clear()
   maestro.modeS.hist.cursor = maestro.modeS.hist.n + 1
end

function EditBase.restartSession(maestro, event)
   maestro.modeS:restart()
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
      modeS:clearResults()
   end
   modeS:agent'edit':insert(value)
end

EditBase.ASCII = _insert
EditBase.UTF8 = _insert

function EditBase.PASTE(modeS, category, value)
   if modeS:agent'edit':contents() == "" then
      modeS:clearResults()
   end
   modeS:agent'edit':paste(value)
end









function EditBase.getCursorPosition(modeS)
   return modeS.zones.command.bounds:origin() + modeS:agent'edit'.cursor - 1
end




return EditBase





local Keymap = require "helm:keymap"
local parts = require "helm:keymap/parts"



local action_bindings = {
   RETURN = "acceptSelected",
   ESC = "userCancel",
   BACKSPACE = "quitIfNoSearchTerm",
   DELETE = "quitIfNoSearchTerm"
}
for i = 1, 9 do
   action_bindings["M-" .. tostring(i)] = { method = "acceptFromNumberKey", n = 1 }
end



return Keymap(
parts.list_selection,
action_bindings,
parts.set_targets("agents.edit", parts.basic_editing),
parts.global_commands)


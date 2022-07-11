


local Keymap = require "helm:keymap"
local parts = require "helm:keymap/parts"



return Keymap(






{
   ["[CHARACTER]"] = { to = "agents.results", method = "clearOnFirstKey" },
   PASTE           = { to = "agents.results", method = "clearOnFirstKey" },
   TAB             = { to = "agents.suggest", method = "activateCompletion" },
   ["S-TAB"]       = { to = "agents.suggest", method = "activateCompletion" },
   ["/"]           = { to = "agents.search",  method = "activateOnFirstKey" },
   ["?"]           = { to = "modeS",          method = "openHelpOnFirstKey" }
},





parts.set_targets("modeS", {
   RETURN = "conditionalEval",
   ["C-RETURN"] = "userEval",
   ["S-RETURN"] = { to = "", method = "nl" },
   ["M-e"] = "evalFromCursor",
   -- Add aliases for terminals not in CSI u mode
   ["C-\\"] = "userEval",
   ["M-RETURN"] = { to = "", method = "nl" }
}),







{
   ["C-b"] = "left",
   ["C-f"] = "right",
   ["C-n"] = "down",
   ["C-p"] = "up",
   -- #todo sneak this in here, it's got nothing
   -- to do with readline but whatever
   ["C-l"] = "clear"
},





parts.basic_editing,
parts.global_commands,





parts.set_targets("modeS", {
   UP = "historyBack",
   DOWN = "historyForward"
}),





parts.set_targets("agents.results", parts.cursor_scrolling)



)


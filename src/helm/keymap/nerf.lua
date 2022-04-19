


local Keymap = require "helm:keymap"
local parts = require "helm:keymap/parts"



return Keymap(






{
   bindings = {
      ["[CHARACTER]"] = { to = "agents.results", method = "clearOnFirstKey" },
      PASTE           = { to = "agents.results", method = "clearOnFirstKey" },
      TAB             = { to = "agents.suggest", method = "activateCompletion" },
      ["S-TAB"]       = { to = "agents.suggest", method = "activateCompletion" },
      ["/"]           = { to = "agents.search",  method = "activateOnFirstKey" },
      ["?"]           = { to = "modeS",          method = "openHelpOnFirstKey" }
   }
},





{
   target = "modeS",
   bindings = {
      RETURN = "conditionalEval",
      ["C-RETURN"] = "userEval",
      ["S-RETURN"] = { to = "agents.edit", method = "nl" },
      ["M-e"] = "evalFromCursor",
      -- Add aliases for terminals not in CSI u mode
      ["C-\\"] = "userEval",
      ["M-RETURN"] = { to = "agents.edit", method = "nl" }
   }
},







{
   target = "agents.edit",
   bindings = {
      ["C-b"] = "left",
      ["C-f"] = "right",
      ["C-n"] = "down",
      ["C-p"] = "up",
      -- #todo sneak this in here, it's got nothing
      -- to do with readline but whatever
      ["C-l"] = "clear"
   }
},





{ target = "agents.edit", bindings = parts.basic_editing },
{ target = "modeS", bindings = parts.global_commands },





{
   target = "modeS",
   bindings = {
      UP = "historyBack",
      DOWN = "historyForward"
   }
},





{ target = "agents.results", bindings = parts.cursor_scrolling }



)


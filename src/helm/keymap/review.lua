


local Keymap = require "helm:keymap"
local parts = require "helm:keymap/parts"




return Keymap({
   target = "agents.session",
   bindings = {
      UP = "selectPreviousWrap",
      DOWN = "selectNextWrap",
      TAB = "toggleSelectedState",
      ["S-TAB"] = "reverseToggleSelectedState",
      ["M-UP"] = "movePremiseUp",
      ["M-DOWN"] = "movePremiseDown",
      RETURN = "editSelectedTitle",
      ["C-q"] = "promptSaveChanges"
   }
}, {
   target = "agents.session.results_agent",
   bindings = parts.cursor_scrolling
}, {
   target = "modeS",
   bindings = parts.global_commands
})


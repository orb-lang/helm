















local concat, insert = assert(table.concat), assert(table.insert)
local sub, gsub, rep = assert(string.sub),
                       assert(string.gsub),
                       assert(string.rep)
local yield = assert(coroutine.yield)






local clone    = import("core/table", "clone")
local EditBase = require "helm:helm/raga/edit"

local Nerf = clone(EditBase, 2)
Nerf.name = "nerf"
Nerf.prompt_char = "👉"






function Nerf.eval(modeS)
   local line = Nerf.agentMessage("edit", "contents")
   local success, results = yield{ call = "eval", n = 1, line }
   if not success and results == 'advance' then
      Nerf.agentMessage("edit", "endOfText")
      return false -- Fall through to EditAgent nl binding
   else
      yield{ sendto = "hist",
             method = "append",
             n = 3,
             line,
             results,
             success }
      yield{ sendto = "hist", method = "toEnd" }
      Nerf.agentMessage("results", "update", results)
      Nerf.agentMessage("edit", "clear")
   end
end

function Nerf.conditionalEval(modeS, category, value)
   if Nerf.agentMessage("edit", "shouldEvaluate") then
      return Nerf.eval(modeS)
   else
      return false -- Fall through to EditAgent nl binding
   end
end

Nerf.keymap_evaluation = {
   RETURN = "conditionalEval",
   ["C-RETURN"] = "eval",
   ["S-RETURN"] = { sendto = "agents.edit", method = "nl" },
   -- Add aliases for terminals not in CSI u mode
   ["C-\\"] = "eval",
   ["M-RETURN"] = { sendto = "agents.edit", method = "nl" }
}






function Nerf.historyBack()
   -- If we're at the end of the history (the user was typing a new
   -- expression), save it before moving
   if yield{ sendto = "hist", method = "atEnd" } then
      local linestash = Nerf.agentMessage("edit", "contents")
      yield{ sendto = "hist", method = "append", n = 1, linestash }
   end
   local prev_line, prev_result = modeS.hist:prev()
   Nerf.agentMessage("edit", "update", prev_line)
   Nerf.agentMessage("results", "update", prev_result)
end

function Nerf.historyForward()
   local new_line, next_result = yield{ sendto = "hist", method = "next" }
   if not new_line then
      local old_line = Nerf.agentMessage("edit", "contents")
      local added = yield{ sendto = "hist", method = "append", n = 1, old_line }
      if added then
         yield{ sendto = "hist", method = "toEnd" }
      end
   end
   Nerf.agentMessage("edit", "update", new_line)
   Nerf.agentMessage("results", "update", next_result)
end

Nerf.keymap_history_navigation = {
   UP = "historyBack",
   DOWN = "historyForward"
}






function Nerf.openHelpOnFirstKey()
   if Nerf.agentMessage("edit", "isEmpty") then
      yield{ method = "openHelp" }
      return true
   else
      return false
   end
end

Nerf.keymap_open_help = {
   ["?"] = "openHelpOnFirstKey"
}









Nerf.default_keymaps = {
   { source = "agents.search", name = "keymap_try_activate" },
   { source = "agents.suggest", name = "keymap_try_activate" },
   { source = "modeS.raga", name = "keymap_open_help" },
   { source = "agents.results", name = "keymap_reset" },






   { source = "modeS.raga", name = "keymap_evaluation" },
   { source = "agents.edit", name = "keymap_readline_nav" }
}





for _, map in ipairs(EditBase.default_keymaps) do
   insert(Nerf.default_keymaps, map)
end





insert(Nerf.default_keymaps,
       { source = "modeS.raga", name = "keymap_history_navigation" })





insert(Nerf.default_keymaps,
      { source = "agents.results", name = "keymap_scrolling" })






local ALT = Nerf.ALT






ALT ["M-e"] = function(modeS, category, value)
   local top = modeS.hist.n
   local cursor = modeS.hist.cursor
   for i = cursor, top do
      -- Discard the second return value from :index
      -- or it will confuse the Txtbuf constructor rather badly
      local line = modeS.hist:index(i)
      modeS:agent'edit':update(line)
      _eval(modeS)
   end
end








function Nerf.onCursorChanged(modeS)
   modeS:agent'suggest':update()
   EditBase.onCursorChanged(modeS)
end

function Nerf.onTxtbufChanged(modeS)
   modeS:agent'suggest':update()
   EditBase.onTxtbufChanged(modeS)
end










local Resbuf = require "helm:buf/resbuf"
function Nerf.onShift(modeS)
   EditBase.onShift(modeS)
   modeS:bindZone("results", "results", Resbuf, { scrollable = true })
   local txtbuf = modeS.zones.command.contents
   txtbuf.suggestions = modeS:agent'suggest':window()
end



return Nerf


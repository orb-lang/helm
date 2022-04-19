















local sub, gsub, rep = assert(string.sub),
                       assert(string.gsub),
                       assert(string.rep)
local table = core.table
local addall, clone, concat, insert, splice = assert(table.addall),
                                              assert(table.clone),
                                              assert(table.concat),
                                              assert(table.insert),
                                              assert(table.splice)
local s = require "status:status" ()







local EditBase = require "helm:helm/raga/edit"

local Nerf = clone(EditBase, 2)
Nerf.name = "nerf"
Nerf.prompt_char = "👉"
Nerf.keymap = require "helm:keymap/nerf"






function Nerf.eval()
   local line = send { to = "agents.edit",
                       method = 'contents' }
   local success, results = send { method = "eval", line }
   s:chat("we return from evaluation, success: %s", success)
   if not success and results == 'advance' then
      send { to = "agents.edit",
             method = 'endOfText'}
      return false -- Fall through to EditAgent nl binding
   else
      send { to = 'hist',
             method = 'append',
             line, results, success }

      send { to = 'hist', method = 'toEnd' }
      -- Do this first because it clears the results area
      -- #todo this clearly means edit:clear() is doing too much, decouple
      send { to = "agents.edit",
                             method = 'clear' }

      send { to = "agents.results",
                     method = 'update', results }
   end
end

function Nerf.conditionalEval()
   if send { to = "agents.edit",
             method = 'shouldEvaluate'} then
      return Nerf.eval()
   else
      return false -- Fall through to EditAgent nl binding
   end
end






function Nerf.historyBack()
   -- If we're at the end of the history (the user was typing a new
   -- expression), save it before moving
   if send { to = 'hist', method = 'atEnd' } then
      local linestash = send { to = "agents.edit", method = "contents" }
      send { to = "hist", method = "append", linestash }
   end
   local prev_line, prev_result = send { to = "hist", method = "prev" }
   send { to = "agents.edit", method = "update", prev_line }
   send { to = "agents.results", method = "update", prev_result }
end

function Nerf.historyForward()
   local new_line, next_result = send { to = "hist", method = "next" }
   if not new_line then
      local old_line = send { to = "agents.edit", method = "contents" }
      local added = send { to = "hist", method = "append", old_line }
      if added then
         send { to = "hist", method = "toEnd" }
      end
   end
   send { to = "agents.edit", method = "update", new_line }
   send { to = "agents.results", method = "update", next_result }
end






function Nerf.evalFromCursor()
   local top = send { to = "hist", property = "n" }
   local cursor = send { to = "hist", property = "cursor" }
   for i = cursor, top do
      local line = send { to = "hist", method = "index", i }
      send { to = "agents.edit", method = "update", line }
      Nerf.eval()
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


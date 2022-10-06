




local core = require "qor:core"
local clone = assert(core.table.clone)
local EditBase = require "helm/raga/edit"

local Complete = clone(EditBase, 2)
local send = Complete.send

Complete.name = "complete"
Complete.prompt_char = "💬"
Complete.keymap = require "helm:keymap/complete"
Complete.lex = require "helm:lex" . lua_thor












function Complete.onTxtbufChanged()
   send { to = 'agents.suggest', method = 'update' }
   if send { to = 'agents.suggest', field = 'last_collection' } then
      send { to = 'agents.suggest', method = "selectFirst" }
   else
      send { method = "popMode" }
   end
   EditBase.onTxtbufChanged()
end










function Complete.onCursorChanged()
   send { method = "popMode" }
   EditBase.onCursorChanged()
end









local Point = require "anterm:point"
function Complete.getCursorPosition()
   local point = EditBase.getCursorPosition()
   local suggestion = send { to = 'agents.suggest', method = 'selectedItem' }
   local tokens = send { to = 'agents.edit', method = 'tokens' }
   if suggestion then
      for _, tok in ipairs(tokens) do
         if tok.cursor_offset then
            point = point + Point(0, #suggestion - tok.cursor_offset)
            break
         end
      end
   end
   return point
end








function Complete.onShift()
   send { to = 'agents.suggest', method = 'selectFirst' }
end








function Complete.onUnshift()
   send { to = 'agents.suggest', method = 'selectNone' }
end



return Complete


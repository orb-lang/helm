













local input_event = require "anterm:input-event"




local Maestro = meta {}














function Maestro.activeKeymaps(maestro)
   return maestro.modeS.raga.default_keymaps
end


















function Maestro.translate(maestro, event)
   local keymaps = maestro:activeKeymaps()
   if not keymaps then return nil end
   local event_string = input_event.serialize(event)
   for _, keymap in ipairs(keymaps) do
      if keymap[event_string] then
         return keymap[event_string]
      end
   end
   return nil
end












function Maestro.dispatch(maestro, event, command, args)
   return maestro.modeS.raga[command](maestro, event, args)
end






local function new(modeS)
   local maestro = meta(Maestro)
   maestro.modeS = modeS
   return maestro
end




return new


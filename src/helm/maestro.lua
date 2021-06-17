















local input_event = require "anterm:input-event"

local InputEchoAgent = require "helm:agent/input-echo"
local StatusAgent = require "helm:agent/status"
local SuggestAgent = require "helm:agent/suggest"

local Resbuf = require "helm:buf/resbuf"
local Stringbuf = require "helm:buf/stringbuf"




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
   -- #todo this is temporary until we sort out communication properly
   maestro.modeS = modeS
   -- Zoneherd we will keep a reference to (maybe the only reference) even
   -- once we untangle from modeS, so start referring to it directly now
   local zones = modeS.zones
   maestro.zones = zones
   local agents = {
      -- edit    = EditAgent(),
      input_echo = InputEchoAgent(),
      -- results = ResultsAgent(),
      status     = StatusAgent(),
      suggest    = SuggestAgent()
   }
   maestro.agents = agents
   -- Set up common Agent -> Zone bindings
   zones.status:replace(Stringbuf(agents.status:window()))
   zones.stat_col
      :replace(Resbuf(agents.input_echo:window()))
   zones.suggest:replace(Resbuf(agents.suggest:window()))
   -- Should be able to talk to EditAgent here and not need the modeS ref
   modeS.txtbuf.suggestions = agents.suggest:window()
   return maestro
end




return new


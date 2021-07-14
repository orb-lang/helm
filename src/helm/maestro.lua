















local input_event = require "anterm:input-event"

local EditAgent      = require "helm:agent/edit"
local InputEchoAgent = require "helm:agent/input-echo"
local ModalAgent     = require "helm:agent/modal"
local PromptAgent    = require "helm:agent/prompt"
local ResultsAgent   = require "helm:agent/results"
local SessionAgent   = require "helm:agent/session"
local StatusAgent    = require "helm:agent/status"
local SuggestAgent   = require "helm:agent/suggest"

local Resbuf    = require "helm:buf/resbuf"
local Stringbuf = require "helm:buf/stringbuf"
local Txtbuf    = require "helm:buf/txtbuf"




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
      edit       = EditAgent(),
      input_echo = InputEchoAgent(),
      modal      = ModalAgent(),
      prompt     = PromptAgent(),
      results    = ResultsAgent(),
      session    = SessionAgent(),
      status     = StatusAgent(),
      suggest    = SuggestAgent()
   }
   maestro.agents = agents
   agents.prompt.edit_window = agents.edit:window()
   -- Set up common Agent -> Zone bindings
   -- Note we don't do results here because that varies from raga to raga
   -- The Txtbuf also needs a source of "suggestions" (which might be
   -- history-search results instead), but that too is raga-dependent
   zones.command:replace(Txtbuf(agents.edit:window()))
   zones.prompt:replace(Stringbuf(agents.prompt:window()))
   zones.modal:replace(Resbuf(agents.modal:window()))
   zones.status:replace(Stringbuf(agents.status:window()))
   zones.stat_col
      :replace(Resbuf(agents.input_echo:window()))
   zones.suggest:replace(Resbuf(agents.suggest:window()))
   return maestro
end




return new


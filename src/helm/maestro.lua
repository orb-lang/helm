















local input_event = require "anterm:input-event"

local EditAgent      = require "helm:agent/edit"
local InputEchoAgent = require "helm:agent/input-echo"
local ModalAgent     = require "helm:agent/modal"
local PagerAgent     = require "helm:agent/pager"
local PromptAgent    = require "helm:agent/prompt"
local ResultsAgent   = require "helm:agent/results"
local SearchAgent    = require "helm:agent/search"
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











function Maestro.bindZone(maestro, zone_name, agent_name, buf_class, cfg)
   local zone = maestro.zones[zone_name]
   local agent = maestro.agents[agent_name]
   zone:replace(buf_class(agent:window(), cfg))
end






local actor = require "core:cluster/actor"
local borrowmethod, getter = assert(actor.borrowmethod, actor.getter)
local function new(modeS)
   local maestro = meta(Maestro)
   -- #todo this is temporary until we sort out communication properly
   maestro.modeS = modeS
   -- Zoneherd we will keep a reference to (maybe the only reference) even
   -- once we untangle from modeS, so start referring to it directly now
   maestro.zones = modeS.zones
   local agents = {
      edit       = EditAgent(),
      input_echo = InputEchoAgent(),
      modal      = ModalAgent(),
      pager      = PagerAgent(),
      prompt     = PromptAgent(),
      results    = ResultsAgent(),
      search     = SearchAgent(),
      session    = SessionAgent(),
      status     = StatusAgent(),
      suggest    = SuggestAgent()
   }
   maestro.agents = agents
   -- Set up Agent <-> Agent interaction via borrowmethod
   local function borrowto(dst, src, name)
      dst[name] = borrowmethod(src, name)
   end
   borrowto(agents.suggest, agents.edit, "tokens")
   borrowto(agents.suggest, agents.edit, "replaceToken")
   borrowto(agents.prompt,  agents.edit, "continuationLines")
   agents.prompt.editTouched = getter(agents.edit, "touched")
   agents.search.searchText = borrowmethod(agents.edit, "contents")
   -- Set up common Agent -> Zone bindings
   -- Note we don't do results here because that varies from raga to raga
   -- The Txtbuf also needs a source of "suggestions" (which might be
   -- history-search results instead), but that too is raga-dependent
   maestro:bindZone("command",  "edit",       Txtbuf)
   maestro:bindZone("popup",    "pager",      Resbuf,    { scrollable = true })
   maestro:bindZone("prompt",   "prompt",     Stringbuf)
   maestro:bindZone("modal",    "modal",      Resbuf)
   maestro:bindZone("status",   "status",     Stringbuf)
   maestro:bindZone("stat_col", "input_echo", Resbuf)
   maestro:bindZone("suggest",  "suggest",    Resbuf)
   return maestro
end




return new


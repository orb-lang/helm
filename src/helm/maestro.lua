















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




local Maestro = meta {}




















local gmatch = assert(string.gmatch)
local insert = assert(table.insert)
local clone = assert(require "core:table" . clone)
local dispatchmessage = assert(require "core:cluster/actor" . dispatchmessage)
function Maestro.activeKeymap(maestro)
   local composed_keymap = { bindings = {}, wildcards = {} }
   local keymap_list = maestro.modeS.raga.default_keymaps
   for _, keymap in ipairs(keymap_list) do
      local bindings = dispatchmessage(maestro, {
         sendto = keymap.source,
         property = keymap.name
      })
      assert(bindings, "Failed to retrieve bindings for " ..
               keymap.source .. "." .. keymap.name)
      for key, action in pairs(bindings) do
         -- #todo assert that this is either a string or Message?
         if type(action) == "string" then
            -- See :dispatch()--by leaving out .n, we cause the command to be
            -- executed with no arguments
            action = { method = action }
         else
            action = clone(action)
         end
         action.sendto = action.sendto or keymap.source
         local key_evt = input_event.marshal(key)
         assert(key_evt, "Failed to parse event string: '" .. key .. "'")
         if key_evt.type == "wildcard" then
            insert(composed_keymap.wildcards, { pattern = key_evt, action = action })
         else
            composed_keymap.bindings[key] = composed_keymap.bindings[key] or {}
            insert(composed_keymap.bindings[key], action)
         end
      end
   end
   return composed_keymap
end









































local concat = assert(table.concat)

local function is_wildcard_match(wc_evt, evt)
   if wc_evt.modifiers ~= evt.modifiers then
      return false
   end
   if evt.type == "keypress" then
      local special = input_event.is_special_key(evt.key)
      if wc_evt.key == "[CHARACTER]" and not special
      or wc_evt.key == "[SPECIAL]" and special then
         return true
      end
   end
   if wc_evt.key == "[MOUSE]" and evt.type == "mouse" then
      return true
   end
   return false
end

local function _dispatchOnly(maestro, event)
   local keymap = maestro:activeKeymap()
   local event_string = input_event.serialize(event)
   local handlers = clone(keymap.bindings[event_string] or {})
   for _, wc_dict in ipairs(keymap.wildcards) do
      if is_wildcard_match(wc_dict.pattern, event) then
         insert(handlers, wc_dict.action)
      end
   end
   local tried = {}
   for _, handler in ipairs(handlers) do
      handler = clone(handler)
      -- #todo make this waaaaay more flexible
      if handler.n and handler.n > 0 then
         handler[handler.n] = event
      end
      -- #todo ugh, some way to dump a Message to a representative string?
      -- #todo also, this is assuming that all traversal is done in `sendto`,
      -- without nested messages--bad assumption, in general
      insert(tried, handler.method or handler.call)
      if dispatchmessage(maestro, handler) ~= false then
         break
      end
   end
   if #tried == 0 then
      return nil
   else
      return concat(tried, ", ")
   end
end

function Maestro.dispatch(maestro, event)
   local command = _dispatchOnly(maestro, event)
   if maestro.agents.edit.contents_changed then
      maestro.modeS.raga.onTxtbufChanged(modeS)
    -- Treat contents_changed as implying cursor_changed
    -- only ever fire one of the two events
   elseif maestro.agents.edit.cursor_changed then
      maestro.modeS.raga.onCursorChanged(modeS)
   end
   maestro.agents.edit.contents_changed = false
   maestro.agents.edit.cursor_changed = false
   return command
end






local function new(modeS)
   local maestro = meta(Maestro)
   -- #todo this is temporary until we sort out communication properly
   maestro.modeS = modeS
   maestro.agents = {
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
   return maestro
end




return new


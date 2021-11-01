















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
   local composed_keymap = {}
   local keymap_list = maestro.modeS.raga.default_keymaps
   for _, keymap in ipairs(keymap_list) do
      if not keymap.bindings then
         keymap = clone(keymap)
         keymap.bindings = dispatchmessage(maestro, {
            sendto = keymap.source,
            property = keymap.name
         })
         assert(keymap.bindings, "Failed to retrieve bindings for " ..
                  keymap.source .. "." .. keymap.name)
      end
      for key, action in pairs(keymap.bindings) do
         -- #todo assert that this is either a string or Message?
         if type(action) == "string" then
            -- See :dispatch()--by leaving out .n, we cause the command to be
            -- executed with no arguments
            action = { method = action }
         else
            action = clone(action)
         end
         action.sendto = keymap.source
         composed_keymap[key] = composed_keymap[key] or {}
         insert(composed_keymap[key], action)
      end
   end
   return composed_keymap
end




























function Maestro.dispatch(maestro, event, old_cat_val)
   local keymap = maestro:activeKeymap()
   local event_string = input_event.serialize(event)
   local command
   -- Handle legacy event first because some legacy cases do multiple things
   -- and may not be fully migrated even if there is a handler for that event
   if old_cat_val and maestro.modeS.raga(maestro.modeS, unpack(old_cat_val)) then
      command = 'LEGACY'
   elseif keymap[event_string] then
      for _, handler in ipairs(keymap[event_string]) do
         -- #todo ugh, some way to dump a Message to a representative string?
         -- #todo also, this is assuming that all traversal is done in `sendto`,
         -- without nested messages--bad assumption, in general
         command = handler.method or handler.call
         handler = clone(handler)
         -- #todo make this waaaaay more flexible
         if handler.n and handler.n > 0 then
            handler[handler.n] = event
         end
         if dispatchmessage(maestro, handler) ~= false then
            break
         end
      end
   end
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


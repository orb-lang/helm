






















































































local cluster = require "cluster:cluster"
local input_event = require "anterm:input-event"
local Message = require "actor:message"

local clone = assert(core.table.clone)






local new, Keymap, Keymap_M = cluster.genus()












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

function Keymap_M.__call(keymap, event)
   local event_string = input_event.serialize(event)
   local handlers = clone(keymap.bindings[event_string] or {})
   for _, wc_dict in ipairs(keymap.wildcards) do
      if is_wildcard_match(wc_dict.pattern, event) then
         insert(handlers, wc_dict.action)
      end
   end
   return handlers
end






cluster.construct(new, function(_, I, ...)
   I.bindings = {}
   I.wildcards = {}
   local declarations = pack(...)
   for _, decl in ipairs(declarations) do
      for key, action in pairs(decl.bindings) do
         -- if idest(action, Message) then
         --    -- #todo be more accomodating here maybe?
         --    assert(action.to, "Messages are immutable, specify your `to` ahead of time if you use them.")
         if type(action) == "string" then
            -- no arguments to commands specified as just a string
            action = { method = action, n = 0 }
         else
            action = clone(action)
            -- #todo should convert to Message, mold() would do this for us
            action.n = action.n or #action
         end
         action.to = action.to or decl.target
         -- #todo but the action ends up being mutated as part of dispatching it,
         -- so converting to Message makes it blow up.
         -- action = Message(action)
         local key_evt = input_event.marshal(key)
         assert(key_evt, "Failed to parse event string: '%s'", key)
         if key_evt.type == "wildcard" then
            insert(I.wildcards, { pattern = key_evt, action = action })
         else
            I.bindings[key] = I.bindings[key] or {}
            insert(I.bindings[key], action)
         end
      end
   end
   return I
end)




return new


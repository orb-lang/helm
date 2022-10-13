# Keymap

A keymap provides the binding from input events to the actions they trigger\.


## Structure

Keymaps exist in three forms:


### Binding declaration

For the sake of convenience, and to avoid repeat\-declaring the source of a
keymap, we declare a keymap as a plain\-old\-table containing only its bindings\.
The keys are event strings as produced/consumed by [https://gitlab.com/special-circumstance/anterm/-/blob/trunk/doc/md/input-event.md](https://gitlab.com/special-circumstance/anterm/-/blob/trunk/doc/md/input-event.md),
and the values are partial `Message`s \(with missing argument\(s\) which will be
filled in when the command is executed\), or in the simple case of a
method\-call with no arguments, just the method name\.

\#todo
into path\-traversal Messages—like `:agent'edit'` could parse into `{ method =\.

"agent", n = 1, 'edit' }`
```lua
{
   UP = "scrollUp",
   SCROLL_DOWN = { method = "evtScrollDown", n = 1 },
   ["[CHARACTER]"] = { method = "selfInsert", n = 1 }
}
```


### Keymap reference

Ragas provide a list of the keymaps they wish to be active in
`<Raga>.default_keymaps`, but of course these **don't** contain any bindings,
only the information needed to retrieve the bindings\-\-a `source` dotted\-path
starting at `maestro`, and a `name` which is a property of the `source` object
containing a binding declaration\.

```lua
Nerf.default_keymaps = {
   ...
   { target = "agents.results", name = "keymap_scrolling" },
   ...
}
```


### Composed keymap

The structure actually used by `Maestro` when dispatching commands needs to
incorporate bindings from many keymap declarations, preserving multiple
bindings to the same event in\-order so they can be tried until one consumes
the event and stops the process\. The `source` of the input keymaps is
transformed into the `to` of the commands in the composed keymap\. We also
extract wildcards to a separate list, as they will not match exactly against
the input event as must be checked manually\.

This is the form implemented by the remainder of this module\.

```lua
{
   bindings = {
      UP = {
         { to = "agents.edit", method = "up" },
         { to = "modeS", method = "historyBack" },
         { to = "agents.results", method = "scrollUp" }
      },
      RETURN = {
         { to = "modeS", method = "conditionalEval" },
         { to = "agents.edit", method = "nl" }
      }
   },
   wildcards = {
      { "[NORMAL]", { to = "agents.edit", method = "selfInsert", n = 1 } },
      -- Not at the same time, of course
      { "M-[NORMAL]",
         { to = "agents.modal", method = "letterShortcut", n = 1 } }
   }
}
```


#### imports

```lua
local core = require "qor:core"
local clone = assert(core.table.clone)

local cluster = require "cluster:cluster"
local input_event = require "anterm:input-event"
local Message = require "actor:message"
```


## Composed\-keymap genus

```lua
local new, Keymap, Keymap_M = cluster.order()
```


### Keymap\(evt\)

Maps an input event to the actions bound to it\. Note we accept the full event
and translate it to a string for lookup internally\.

\#todo
be a single action name?

```lua
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
```


### Keymap constructor\(declarations\.\.\.\)

```lua
cluster.construct(new, function(_, I, ...)
   I.bindings = {}
   I.wildcards = {}
   local declarations = pack(...)
   for _, decl in ipairs(declarations) do
      for key, action in pairs(decl) do
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
```


```lua
return new
```

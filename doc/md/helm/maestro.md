# Maestro

The Maestro is\.\.\.I'm not sure yet, but for now it's where I'm going to put the
keymap\-resolver logic, and when we need to start buffering commands, switching
to sub\-keymaps, or whatever we do for vril\-style commands, that'll be here
too\.

This will eventually be the home for all the Agents, and possibly some
non\-Agent Actors as well\. We will eventually communicate with modeS via
coroutine yield/resume, but for now, between Agents not yet migrated and not
**having** said mechanism, we just keep a reference to modeS\.


#### imports

```lua
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
```


```lua
local Maestro = meta {}
```


## Keymap resolution


### Maestro:activeKeymap\(\)

Builds a composed keymap from the active keymap references provided by the raga\.

\#todo
with a \`yield\`ed message? Sticking with the backlink for now because anything
else is suuuuuuper ugly\.

\#todo
every command\.

\#todo

```lua
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
```


### Maestro:dispatch\(event\)

Dispatches `event` to the handler\(s\) specified in the active keymaps\. Each
handler may answer a boolean indicating whether the event should be considered
handled, or whether execution should continue\. Note that we look only for an
explicit `false` return value to fall through to the next handler\. Any other
value, specifically including `nil`, stops execution\.

\#todo
they "did something"\-\-successfully moved the cursor or deleted something\. In
their case we don't always want to fall through\.

Wildcard bindings are checked after all specific bindings, no matter which
keymap they each come from\. In other words, if we have keymaps A and B, and A
contains a matching wildcard binding, but B contains a matching specific
binding, the binding from B wil be executed first \(and may stop subsequent
commands from executing at all\)\. Partly this makes things easier to implement,
since a composed keymap can just throw all the wildcards in one pile and not
worry about where they came from, but it also seems reasonable that they are
of a lower logical priority than specific bindings\.

\#todo
processed to determine arguments to pass to the actual handler\. Not sure
that'll come up for "simple" commands\-\-almost by definition the event itself
is enough information for the command to figure things out\-\-but once we start
buffering for `vril` this is where we would deal with that\.

\#todo
active keymaps\) changes during command execution, and the handler wants to
fall through\. Right now we have the \`modeS\.action\_complete\` mechanism, but I'd
like to unify and remove that\. The question then is how to manipulate the list
of remaining handlers\. The only obvious thing is to rebuild the composed
keymap, redo the lookup, and start over from the beginning of the new list of
bindings \(which is equivalent to the action\_complete behavior\), relying on the
handler to ensure that it is no longer **in** that list and won't be executed
again\. Hard to say what the right thing to do here is\.\.\.

```lua
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
```


### new\(modeS\)

```lua
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
```


```lua
return new
```
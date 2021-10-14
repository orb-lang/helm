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

Builds a composed keymap from the active keymaps as provided by the raga\.
A non\-composed keymap looks like:

```lua
{
   source = "agents.edit",
   name = "basic_editing_keymap",
   bindings = {
      "BACKSPACE" = "deleteBackward"
      ...
   }
}
```

`bindings` is optional at this stage; if absent, it will be retrieved by
traversing to the actual `source` \(which is a dotted path starting at
`maestro`\) and retrieving the property at `name`\.

The composed keymap is similar, except that the values in `bindings` are lists
of Messages \(whose `sendto` directs them to the `source` of the keymap they
came from\) representing possible handlers\.

\#todo
into path\-traversal Messages—like `:agent'edit'` could parse into `{ method =\.

"agent", n = 1, 'edit' }`
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
```


### Maestro:dispatch\(event, old\_cat\_val\)

Dispatches `event` to the handler\(s\) specified in the active keymaps\. Each
handler may answer a boolean indicating whether the event should be considered
handled, or whether execution should continue\. Note that we look only for an
explicit `false` return value to fall through to the next handler\. Any other
value, specifically including `nil`, stops execution\.

For now, we also accept the old \{category, value\} style of event, dispatching
it to a special LEGACY handler on the raga if no match is found for the
new\-style event\.

\#todo
processed to determine arguments to pass to the actual handler\. Not sure
that'll come up for "simple" commands\-\-almost by definition the event itself
is enough information for the command to figure things out\-\-but once we start
buffering for `vril` this is where we would deal with that\.

\#todo
active keymaps\) changes during command execution, and the handler wants to
fall through\. I guess for now, we just retry from the start of the new list,
relying on the handler to ensure that it is no longer **in** that list and won't
be executed again? Hard to say what the right thing to do here is\.\.\.

```lua
function Maestro.dispatch(maestro, event, old_cat_val)
   local keymap = maestro:activeKeymap()
   local event_string = input_event.serialize(event)
   local command
   -- Handle legacy event first because some legacy cases do multiple things
   -- and may not be fully migrated even if there is a handler for that event
   if maestro.modeS.raga(maestro.modeS, unpack(old_cat_val)) then
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
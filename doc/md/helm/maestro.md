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

local InputEchoAgent = require "helm:agent/input-echo"
```


```lua
local Maestro = meta {}
```


## Keymap resolution


### Maestro:activeKeymaps\(\)

Determines the list of active keymaps\.

\#todo
retrieved wholesale from the raga\.

```lua
function Maestro.activeKeymaps(maestro)
   return maestro.modeS.raga.default_keymaps
end
```


### Maestro:translate\(event\)

Searches the active keymaps for `event`, and returns the command name to
execute, or nil if none is found\.

\#todo
command as well\. Not sure that'll come up for "simple" commands\-\-almost by
definition the event itself is enough information for the command to figure
things out\-\-but once we start buffering for `vril` this is where we would deal
with that\. Maybe if we come up with any args we **don't** actually hand the raw
event to the command? In the `vril` case it's pretty useless really\.\.\. In that
case we would need to return the event as the sole arg in the case where we
**do** want it, rather than the calling code passing it unconditionally\.

```lua
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
```


### Maestro:dispatch\(event, command\[, args\]\)

Given a command name \(and optional arguments\), finds the function implementing
the command and executes it\.

\#todo
by the definition of the command somehow?

```lua
function Maestro.dispatch(maestro, event, command, args)
   return maestro.modeS.raga[command](maestro, event, args)
end
```


### new\(modeS\)

```lua
local function new(modeS)
   local maestro = meta(Maestro)
   maestro.modeS = modeS
   maestro.agents = {
      -- edit = EditAgent(),
      input_echo = InputEchoAgent(),
      -- results = ResultsAgent(),
      -- status = StatusAgent(),
   }
   return maestro
end
```


```lua
return new
```
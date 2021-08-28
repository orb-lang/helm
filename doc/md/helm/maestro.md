# Maestro

The Maestro is...I'm not sure yet, but for now it's where I'm going to put the
keymap-resolver logic, and when we need to start buffering commands, switching
to sub-keymaps, or whatever we do for vril-style commands, that'll be here
too.


This will eventually be the home for all the Agents, and possibly some
non-Agent Actors as well. We will eventually communicate with modeS via
coroutine yield/resume, but for now, between Agents not yet migrated and not
**having** said mechanism, we just keep a reference to modeS.


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


### Maestro:activeKeymaps()

Determines the list of active keymaps.

```lua
function Maestro.activeKeymaps(maestro)
   return maestro.modeS.raga.default_keymaps
end
```
### Maestro:translate(event)

Searches the active keymaps for ``event``, and returns the command name to
execute, or nil if none is found.

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
### Maestro:dispatch(event, command[, args])

Given a command name (and optional arguments), finds the function implementing
the command and executes it.

```lua
function Maestro.dispatch(maestro, event, command, args)
   return maestro.modeS.raga[command](maestro, event, args)
end
```
### new(modeS)

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

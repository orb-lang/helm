# Agent base class

An Agent is a particular kind of [Actor](httk://) which is responsible for
implementing responses to input events, and drives a region of the screen by
providing a [Window](@window) that is the `source` for a
[Rainbuf](@helm:buf/rainbuf)\.


#### imports

```lua
local Window = require "window:window"
-- local Deque = require "deque:deque"
```


```lua
local meta = assert(require "core:cluster" . Meta)
local Agent = meta {}
```


### Agent:checkTouched\(\)

```lua
function Agent.checkTouched(agent)
   local touched = agent.touched
   agent.touched = false
   return touched
end
```


### Agent:bufferValue\(\)

Abstract method\. Return the primary value which should be displayed in the
Rainbuf associated with this Agent\.


### Agent:window\(\)

The `Window`s of `Agent`s need to implement some common behavior in order to
interact correctly with `Rainbuf`s and change detection, so we start with a
basic config\. Subclasses may override `:windowConfiguration()` to add their
own details, using `.mergeWindowConfig()` to include the superclass' config\.Note that this is not a method, just a function\.\)

\(
```lua
local addall = assert(require "core:table" . addall)
function Agent.mergeWindowConfig(cfg_a, cfg_b)
   for cat, props in pairs(cfg_b) do
      cfg_a[cat] = cfg_a[cat] or {}
      addall(cfg_a[cat], props)
   end
   return cfg_a
end

function Agent.windowConfiguration(agent)
   return {
      field = { touched = true },
      fn = { buffer_value = function(agent, window, field)
         return agent:bufferValue()
      end },
      closure = { checkTouched = true }
   }
end

function Agent.window(agent)
   return Window(agent, agent:windowConfiguration())
end
```


### Agent\(\)

At the moment, Agents are generally constructed with no parameters, and any
needed values are filled in later\. Some do need to set up some initial state,
so we provide an `_init` method\. \#todo should we in fact have some arguments
to the constructor?

```lua
function Agent._init(agent)
   return
end

function Agent.__call(agent_class)
   local agent_M = getmetatable(agent_class)
   local agent = setmetatable({}, agent_M)
   agent:_init()
   return agent
end
```


```lua
local constructor = assert(require "core:cluster" . constructor)
return constructor(Agent)
```

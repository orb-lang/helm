# Agent utils

Some functions commonly needed as methods on Agents, and some utils to assist
in constructing them\.

```lua
local agent_utils = {}
```


### checkTouched\(\)

This implementation is used by things that aren't Agents, though they are Actors\.

```lua
function agent_utils.checkTouched(agent)
   local touched = agent.touched
   agent.touched = false
   return touched
end
```


### Basic Window config

The `Window`s of `Agent`s need to implement some common behavior in order to
interact correctly with `Rainbuf`s and change detection, so much of the config
can be standardized\.

We need to produce a new copy of the config each time, and also we want to
make it easy to extend, so we return a function that accepts additional config
options, merges the two and returns a new table\.

```lua
local addall = assert(require "core:table" . addall)
local function make_window_cfg(more_cfg)
   local cfg = {
      field = { touched = true },
      closure = { checkTouched = true }
   }
   for cat, props in pairs(more_cfg) do
      cfg[cat] = cfg[cat] or {}
      addall(cfg[cat], props)
   end
   return cfg
end
```


### make\_window\_method\(cfg\)

Constructs a function that can be installed as `AgentClass:window()`, with
config based on the provided cfg plus some common behavior\.

```lua
local Window = require "window:window"

function agent_utils.make_window_method(more_cfg)
   local window_cfg = make_window_cfg(more_cfg)
   return function(agent)
      -- #todo is it reasonable for Agents to cache their window like this?
      -- Is it reasonable for others to *assume* that they will (if it even matters)?
      agent._window = agent._window or Window(agent, window_cfg)
      return agent._window
   end
end
```

```lua
return agent_utils
```
# ResultsAgent

Agent for results display\. For now this turns out to be the simplest of the
lot, basically just a dumb value holder\. It may get some more responsibility
later, not sure\.

```lua
local ResultsAgent = meta {}
```


### ResultsAgent:update\(result\)

```lua
function ResultsAgent.update(agent, result)
   agent.buffer_value = result or { n = 0 }
   agent.touched = true
end
```


### Window

```lua
local agent_utils = require "helm:agent/utils"

ResultsAgent.checkTouched = agent_utils.checkTouched

ResultsAgent.window = agent_utils.make_window_method({
   field = { buffer_value = true }
})
```


### new

```lua
local function new()
   local agent = meta(ResultsAgent)
   agent.buffer_value = { n = 0 }
   return agent
end
```

```lua
ResultsAgent.idEst = new
return new
```
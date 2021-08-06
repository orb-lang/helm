# ResultsAgent

Agent for results display\. For now this turns out to be the simplest of the
lot, basically just a dumb value holder\. It may get some more responsibility
later, not sure\.

```lua
local meta = assert(require "core:cluster" . Meta)
local Agent = require "helm:agent/agent"
local ResultsAgent = meta(getmetatable(Agent))
```


### ResultsAgent:update\(result\), :clear\(\)

```lua
function ResultsAgent.update(agent, result)
   agent.result = result
   agent.touched = true
end

function ResultsAgent.clear(agent)
   agent:update(nil)
end
```


### ResultsAgent:bufferValue\(\)

```lua
function ResultsAgent.bufferValue(agent)
   return agent.result or { n = 0 }
end
```


```lua
local ResultsAgent_class = setmetatable({}, ResultsAgent)
ResultsAgent.idEst = ResultsAgent_class

return ResultsAgent_class
```
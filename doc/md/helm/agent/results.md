# ResultsAgent

Agent for results display\. For now this turns out to be the simplest of the
lot, basically just a dumb value holder\. It may get some more responsibility
later, not sure\.

#### imports

```lua
local cluster = require "cluster:cluster"
local Agent = require "helm:agent/agent"
```


### ResultsAgent\(\)

```lua
local new, ResultsAgent = cluster.genus(Agent)
cluster.extendbuilder(new, true)
```


### ResultsAgent:update\(result\), :clear\(\)

```lua
function ResultsAgent.update(agent, result)
   agent.result = result
   agent:contentsChanged()
   agent:scrollToTop()
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


### ResultsAgent:clearOnFirstKey\(\)

Clear the results if the EditAgent is currently empty, i\.e\. the event being
processed will be the first character in the buffer\.

```lua
function ResultsAgent.clearOnFirstKey(agent)
   if agent :send { to = "agents.edit", method = "isEmpty" } then
      agent:clear()
   end
   return false
end
```


```lua
return new
```

# PagerAgent

Agent for displaying simple content \(e\.g\. help files\)\.

#### imports

```lua
local cluster = require "cluster:cluster"
local Agent = require "helm:agent/agent"
```


### PagerAgent\(\)

```lua
local new, PagerAgent = cluster.genus(Agent)
cluster.extendbuilder(new, true)
```


### PagerAgent:update\(result\), :clear\(\)

```lua
function PagerAgent.update(agent, str)
   agent.str = str
   agent:contentsChanged()
end

function PagerAgent.clear(agent)
   agent:update(nil)
end
```


### PagerAgent:activate\(\), :quit\(\)

Activate/dismiss the pager \(showing/hiding the popup Zone in the process\)\.

```lua
function PagerAgent.activate(agent)
   agent :send { method = "pushMode", "page" }
end
function PagerAgent.quit(agent)
   agent :send { method = "popMode" }
end
```


### PagerAgent:bufferValue\(\)

```lua
function PagerAgent.bufferValue(agent)
   -- #todo we should work with a Rainbuf that does word-aware wrapping
   -- and accepts a string directly, rather than abusing Resbuf
   return { n = 1, agent.str }
end
```


```lua
return new
```

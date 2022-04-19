# PagerAgent

Agent for displaying simple content \(e\.g\. help files\)\.

```lua
local table = core.table

local Agent = require "helm:agent/agent"
local PagerAgent = meta(getmetatable(Agent))
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
   agent :send { method = "shiftMode", "page" }
end
function PagerAgent.quit(agent)
   agent :send { method = "shiftMode", "default" }
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
return core.cluster.constructor(PagerAgent)
```

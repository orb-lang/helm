# Result\-list Agent

An abstract Agent class implementing common behavior for Agents that manage a
list of results of some kind\.


#### imports

```lua
local SelectionList = require "helm:selection_list"
```


```lua
local meta = assert(require "core:cluster" . Meta)
local Agent = require "helm:agent/agent"
local ResultListAgent = meta(getmetatable(Agent))
```


### ResultListAgent:bufferValue\(\)

```lua
function ResultListAgent.bufferValue(agent)
   return agent.last_collection and { n = 1, agent.last_collection }
end
```


### ResultListAgent:windowConfiguration\(\)

```lua
local function _toLastCollection(agent, window, field, ...)
   local lc = agent.last_collection
   return lc and lc[field](lc, ...) -- i.e. lc:<field>(...)
end

function ResultListAgent.windowConfiguration(agent)
   -- #todo super is hella broken, grab explicitly from the right superclass
   return agent.mergeWindowConfig(Agent.windowConfiguration(agent), {
      closure = {
         selectedItem = _toLastCollection,
         highlight = _toLastCollection
      }
   })
end
```


```lua
local ResultListAgent_class = setmetatable({}, ResultListAgent)
ResultListAgent.idEst = ResultListAgent_class

return ResultListAgent_class
```

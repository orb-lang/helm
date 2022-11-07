# Result\-list Agent

An abstract Agent class implementing common behavior for Agents that manage a
list of results of some kind\.


#### imports

```lua
local cluster = require "cluster:cluster"
local Agent = require "helm:agent/agent"

local SelectionList = require "helm:selection_list"
```


### ResultListAgent\(\)

```lua
local new, ResultListAgent = cluster.genus(Agent)
cluster.extendbuilder(new, function(_new, agent)
   agent.topic = SelectionList('')
   return agent
end)
```


### Selection methods

We wrap `select*` methods of `SelectionList` to also re\-render and make sure
the new selection is visible\.

```lua
for _, method_name in ipairs{"selectNext", "selectPrevious",
                    "selectNextWrap", "selectPreviousWrap",
                    "selectFirst", "selectIndex", "selectNone"} do
   ResultListAgent[method_name] = function(agent, ...)
      agent.topic[method_name](agent.topic, ...)
      agent:contentsChanged()
      agent:bufferCommand("ensureVisible", agent.topic.selected_index)
   end
end
```

And a forwarder for :selectedItem\(\)

```lua
function ResultListAgent.selectedItem(agent)
   return agent.topic:selectedItem()
end
```


### ResultListAgent:hasResults\(\)

```lua
function ResultListAgent.hasResults(agent)
   return #agent.topic > 0
end
```


### ResultListAgent:quit\(\)

Quits the raga associated with the agent, returning to the previous raga\.

```lua
function ResultListAgent.quit(agent)
   agent:selectNone()
   agent :send { method = "popMode" }
end
```


### ResultListAgent:bufferValue\(\)

```lua
function ResultListAgent.bufferValue(agent)
   return { n = 1, agent.topic }
end
```


### ResultListAgent:windowConfiguration\(\)

```lua
local function _toTopic(agent, window, field, ...)
   return agent.topic[field](agent.topic, ...) -- i.e. topic:<field>(...)
end

function ResultListAgent.windowConfiguration(agent)
   -- #todo super is hella broken, grab explicitly from the right superclass
   return agent.mergeWindowConfig(Agent.windowConfiguration(agent), {
      closure = {
         selectedItem = _toTopic,
         highlight = _toTopic
      }
   })
end
```


```lua
return new
```

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
   agent:contentsChanged()
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
   if send { sendto = "agents.edit", method = "isEmpty" } then
      agent:clear()
   end
   return false
end
```

### Keymaps

```lua
ResultsAgent.keymap_reset = {
   ["[CHARACTER]"] = "clearOnFirstKey",
   PASTE = "clearOnFirstKey"
}
```


```lua
local constructor = assert(require "core:cluster" . constructor)
return constructor(ResultsAgent)
```

# PagerAgent

Agent for results display\. For now this turns out to be the simplest of the
lot, basically just a dumb value holder\. It may get some more responsibility
later, not sure\.

```lua
local PagerAgent = meta {}
```


### PagerAgent:update\(result\), :clear\(\)

```lua
function PagerAgent.update(agent, str)
   agent.str = str
   agent.touched = true
end

function PagerAgent.clear(agent)
   agent:update(nil)
end
```


### Window

```lua
local agent_utils = require "helm:agent/utils"

PagerAgent.checkTouched = agent_utils.checkTouched

PagerAgent.window = agent_utils.make_window_method({
   fn = { buffer_value = function(agent, window, field)
      -- #todo we should work with a Rainbuf that does word-aware wrapping
      -- and accepts a string directly, rather than abusing Resbuf
      return { n = 1, agent.str }
   end }
})
```


### new

```lua
local function new()
   return meta(PagerAgent)
end
```

```lua
PagerAgent.idEst = new
return new
```
# PromptAgent

Agent supplying the prompt\. The prompt character is supplied by the raga,
we're just a dumb value holder for that, but we do retrieve the number of
continuation lines from a reference to the EditAgent's Window\.

```lua
local meta = assert(require "core:cluster" . Meta)
local Agent = require "helm:agent/agent"
local PromptAgent = meta(getmetatable(Agent))
```


### PromptAgent:update\(prompt\_char\)

```lua
function PromptAgent.update(agent, prompt_char)
   agent.prompt_char = prompt_char
   agent.touched = true
end
```


### PromptAgent:checkTouched\(\)

Changes to the number of continuation lines also affect us\. Easiest to just
consider ourselves touched whenever the EditAgent is, not like painting the
prompt is expensive\.

```lua
function PromptAgent.checkTouched(agent)
   -- #todo .touched propagation is weird, we can't :checkTouched()
   -- on the EditAgent because we'll clear stuff prematurely
   agent.touched = agent.touched or agent.editTouched()
   return Agent.checkTouched(agent)
end
```


### PromptAgent:bufferValue\(\)

```lua
function PromptAgent.bufferValue(agent)
   return agent.prompt_char .. " " .. ("\n..."):rep(agent.continuationLines())
end
```


```lua
local constructor = assert(require "core:cluster" . constructor)
return constructor(PromptAgent)
```

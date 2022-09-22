# Status Agent

A simple Agent providing a status\-bar display with standard and custom messages\.


#### imports

```lua
local cluster = require "cluster:cluster"
local Agent = require "helm:agent/agent"
```


### StatusAgent\(\)

```lua
local new, StatusAgent = cluster.genus(Agent)

cluster.extendbuilder(new, function(_new, agent)
   agent.status_name = 'default'
   agent.format_args = { n = 0 }
   return agent
end)
```


\#/lua


### Available status lines

```lua
local status_lines = {
   default            = "an repl, plz reply uwu 👀",
   quit               = "exiting repl, owo... 🐲",
   restart            = "restarting an repl ↩️",
   session_review     = 'reviewing session "%s"',
   run_review_initial = 'Press Return to Evaluate, Tab/Up/Down to Edit',
   run_review         = 'Press M-e to Evaluate' }
status_lines.new_session = status_lines.default .. ' (recording "%s")'
```


### StatusAgent:update\(status\_name, format\_args\.\.\.\)

Sets which status line is displayed\. `status_name` selects a format string
from the list below, and any additional parameters are passed through to
`string.format`\.

```lua
function StatusAgent.update(stat, status_name, ...)
   stat.status_name = status_name
   stat.format_args = pack(...)
   stat:contentsChanged()
end
```


### StatusAgent:bufferValue\(\)

```lua
function StatusAgent.bufferValue(stat)
   return status_lines[stat.status_name]:format(unpack(stat.format_args))
end
```


```lua
return new
```

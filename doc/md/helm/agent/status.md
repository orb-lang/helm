# Status Agent

A simple Agent providing a status\-bar display with standard and custom messages\.


```lua
local meta = assert(require "core:cluster" . Meta)
local Agent = require "helm:agent/agent"
local StatusAgent = meta(getmetatable(Agent))
```


### Available status lines

```lua
local status_lines = { default = "an repl, plz reply uwu 👀",
                       quit    = "exiting repl, owo... 🐲",
                       restart = "restarting an repl ↩️",
                       review  = 'reviewing session "%s"' }
status_lines.macro       = status_lines.default .. ' (macro-recording "%s")'
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


### StatusAgent:\_init\(\)

```lua
function StatusAgent._init(agent)
   Agent._init(agent)
   agent.status_name = 'default'
   agent.format_args = { n = 0 }
end
```


```lua
local constructor = assert(require "core:cluster" . constructor)
return constructor(StatusAgent)
```

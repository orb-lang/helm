# Riff\-round/round review agent

\(Sub\)\-agent used when reviewing a Session or interactive restart\. Manages
state for an individual round\.

#### imports

```lua
local cluster = require "cluster:cluster"
local Agent = require "helm:agent/agent"
```


### RiffRoundAgent\(\)

```lua
local new, RiffRoundAgent = cluster.genus(Agent)
cluster.extendbuilder(new, true)
```


```lua
return new
```
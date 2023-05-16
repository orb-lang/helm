# Run\-review \(interactive\-restart\) agent

Agent responsible for interactive editing of a previous run
before restarting it\.


#### imports

```lua
local core = require "qor:core"
local table = core.table

local cluster = require "cluster:cluster"
local ReviewAgent = require "helm:agent/review"

local Round = require "helm:round"
```


### RunReviewAgent\(\)

```lua
local new, RunReviewAgent = cluster.genus(ReviewAgent)
cluster.extendbuilder(new, true)
```


### RunReviewAgent:setInitialSelection\(\)

We never operate on an empty topic\-\-if we don't have anything, add a blank
"insert" round so we have somewhere to start\.

```lua
local insert = assert(table.insert)
function RunReviewAgent.setInitialSelection(agent)
   if #agent.topic == 0 then
      insert(agent.topic, Round():asRiffRound{ status = "insert" })
   end
   agent.selected_index = 1
end
```


```lua
RunReviewAgent.insert_after_status = "keep"
```


### RunReviewAgent:evalAndResume\(\)

Finishes the review process, evaluating all non\-trashed rounds\.

```lua
local Deque = require "deque:deque"
function RunReviewAgent.evalAndResume(agent)
   -- Clear out any insertion-in-progress
   agent:cancelInsertion()
   local to_run = Deque()
   for _, round in ipairs(agent.topic) do
      if round.status == "keep" then
         to_run:push(round:asRound())
      end
   end
   agent :send { to = "agents.status", method = "update", "default" }
   agent :send { method = "pushMode", "nerf" }
   agent :send { method = "rerun", to_run }
end
```


```lua
return new
```

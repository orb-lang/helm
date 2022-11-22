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
      -- #todo this shouldn't be a Premise but some other Round specialization
      insert(agent.topic, Round():asPremise{ status = "insert" })
   end
   agent.selected_index = 1
end
```


## Editing


### Status list

This is the cycle order when pressing Tab/Shift\-Tab, but there is a
complication, because "insert" is not really a legal state for
already\-existing rounds\. Instead, attempting to switch to it inserts a **new**
blank round with that state, and leaving it removes that round, **without**
changing the state of the now\-re\-selected following round\. This would leave us
stuck in a loop between "keep" and "insert" \(or "trash" and "insert" when
cycling backwards\), so we also maintain a flag indicating whether we just leftinsert"\. If this is set and we **would** switch to "insert", we skip over it
and
" go to whatever's next/previous in the order\.

```lua
RunReviewAgent.valid_statuses = { "keep", "insert", "trash" }
RunReviewAgent.was_inserting = false
```


### Insertion and editing


#### RunReviewAgent:insertRound\(\)

Insert a blank round with "insert" status before the currently\-selected round,
thus selecting it\.

```lua
function RunReviewAgent.insertRound(agent)
   local round = Round():asPremise{ status = "insert" }
   insert(agent.topic, agent.selected_index, round)
   -- These agents are lazy-initialized, so we can
   -- just make room (with table stuffing)...
   insert(agent.edit_agents, agent.selected_index, false)
   -- ...and inform the buffer
   agent:bufferCommand("roundInserted", agent.selected_index)
   agent:_updateResultsAgent()
end
```


#### RunReviewAgent:cancelInsertion\(\)

If the selected round is blank, with "insert" status, remove it and set the
`was_inserting` flag\. Intended as an unconditional guard sent before any
attempted selection change, so we just do nothing if the selected round
isn't in "insert" state\.

```lua
local remove = assert(table.remove)
function RunReviewAgent.cancelInsertion(agent)
   if agent:selectedRound().status ~= "insert"
      -- Don't remove an "insert" round if it's the very last one
      or #agent.topic == 1 then
         return
   end
   remove(agent.topic, agent.selected_index)
   remove(agent.edit_agents, agent.selected_index)
   agent:bufferCommand("roundRemoved", agent.selected_index)
   agent:_updateResultsAgent()
   agent.was_inserting = true
end
```


#### RunReviewAgent:setSelectedState\(state\)

We need to perform additional bookkeeping to add or remove a blank round when
changing to/from insert status\.

```lua
function RunReviewAgent.setSelectedState(agent, state)
   local round = agent:selectedRound()
   if round.status == state then return end
   -- Any status change clears the `was_inserting` flag, *except* canceling
   -- out of insertion, which sets it instead. Save it locally and clear it
   -- before deciding what to do, that way it can just be *re*-set in the
   -- one case that needs it.
   local was_inserting = agent.was_inserting
   agent.was_inserting = false
   if state == "insert" then
      if was_inserting then
         -- #todo this is dependent on only having two non-insert statuses,
         -- if there were more, we would need to know the intended
         -- cycle direction, so this would need to become an assertion failure
         -- and we would have to handle this in overrides of
         -- :[reverse]ToggleSelectedState
         state = round.status == "keep" and "trash" or "keep"
         ReviewAgent.setSelectedState(agent, state)
      else
         agent:insertRound()
      end
   else
      -- Need to explicitly check here because we don't want to change another
      -- round's status when canceling out of insertion. Setting the flag
      -- means the change will occur the *next* time tab is pressed
      if round.status == "insert" then
         agent:cancelInsertion()
      else
         ReviewAgent.setSelectedState(agent, state)
      end
   end
end
```


#### RunReviewAgent:selectionChanged\(\)

Any selection change clears the `was_inserting` flag\. It may have been set
earlier in the same operation when pressing up/down with an "insert" round
selected\-\-this is correct behavior, the only time the flag matters is when
repeatedly pressing \[Shift\-\]Tab\.

```lua
function RunReviewAgent.selectionChanged(agent)
   agent.was_inserting = false
   ReviewAgent.selectionChanged(agent)
end
```


#### RunReviewAgent:selectIndex\(i\), :select\{Next|Previous\}Wrap\(\)

Cancel/remove any "insert" round before changing selection\. We guard against
any selection change, but in practice all selection changes right now go
through `:select{Next|Previous}Wrap`\-\-which is good, becausecancelInsertion\(\) may shift part of the list by one, throwing off the meaning
of
: the index if it was computed first\. Thus we separately override
`:select{Next|Previous}Wrap()` to perform any such shuffling before computing
what index to select\.

```lua
function RunReviewAgent.selectIndex(agent, index)
   agent:cancelInsertion()
   ReviewAgent.selectIndex(agent, index)
end
function RunReviewAgent.selectNextWrap(agent)
   agent:cancelInsertion()
   ReviewAgent.selectNextWrap(agent)
end
function RunReviewAgent.selectPreviousWrap(agent)
   agent:cancelInsertion()
   ReviewAgent.selectPreviousWrap(agent)
end
```


#### RunReviewAgent:editLine\(\)

Begin editing the line of the selected round\.

```lua
function RunReviewAgent.editLine(agent)
   local line = agent:selectedRound():getLine()
   agent :send { to = "agents.edit", method = "update", line }
   agent :send { method = "pushMode", "edit_line"}
end
```


#### RunReviewAgent:cancelLineEdit\(\)

Cancel out of line editing, discarding changes\.

```lua
function RunReviewAgent.cancelLineEdit(agent)
   agent:cancelInsertion()
   agent :send { to = "agents.edit", method = "clear" }
   agent :send { method = "popMode" }
end
```


#### RunReviewAgent:acceptLineEdit\(\)

Accept the line in the edit buffer and update the selected round, changing it
from "insert" to "accept" if needed and moving to the next round\. An empty
string is not a valid/interesting line, so we either stay in "insert" state or
change to "trash" and the selection remains in place\.

```lua
function RunReviewAgent.acceptLineEdit(agent)
   local line = agent :send { to = "agents.edit", method = "contents" }
   agent :send { to = "agents.edit", method = "clear" }
   local round = agent:selectedRound()
   if line:find("^%s*$") then
      if round.status ~= "insert" then
         round.status = "trash"
      end
   else
      round:setLine(line)
      -- Switch out the status without going through the usual channels
      -- so that we don't remove the newly-added round in the process
      if round.status == "insert" then
         round.status = "keep"
      end
      agent:_updateEditAgent(agent.selected_index)
      agent:selectNextWrap()
   end
   agent :send { method = "popMode" }
end
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

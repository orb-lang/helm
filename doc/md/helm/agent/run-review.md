# Run\-review \(interactive\-restart\) agent

Agent responsible for interactive editing of a previous run
before restarting it\.


#### imports

```lua
local table = core.table
```


```lua
local ReviewAgent = require "helm:agent/review"
local RunReviewAgent = meta(getmetatable(ReviewAgent))
```


### RunReviewAgent:update\(lines\)

```lua
local insert = assert(table.insert)
function RunReviewAgent.update(agent, lines)
   agent.subject = {}
   while not lines:isEmpty() do
      insert(agent.subject, { line = lines:pop(), status = "keep" })
   end
   if #agent.subject == 0 then
      insert(agent.subject, { line = "", status = "insert" })
   end
   agent.selected_index = 1
   agent:_updateResultsAgent()
   -- Update any EditAgents we have without creating any more
   for index in pairs(agent.edit_agents) do
      agent:_updateEditAgent(index)
   end
   agent:contentsChanged()
end
```


## Editing


### Status list

This is the cycle order when pressing Tab/Shift\-Tab, but there is a
complication, because "insert" is not really a legal state for
already\-existing lines\. Instead, attempting to switch to it inserts a **new**
blank line with that state, and leaving it removes that line, **without**
changing the state of the now\-re\-selected following line\. This would leave us
stuck in a loop between "keep" and "insert" \(or "trash" and "insert" when
cycling backwards\), so we also maintain a flag indicating whether we just left
"insert"\. If this is set and we **would** switch to "insert", we skip over it
and go to whatever's next/previous in the order\.

```lua
RunReviewAgent.valid_statuses = { "keep", "insert", "trash" }
RunReviewAgent.was_inserting = false
```


### Line insertion


#### RunReviewAgent:insertLine\(\)

Insert a blank line with "insert" status before the currently\-selected premise,
thus selecting it\.

```lua
function RunReviewAgent.insertLine(agent)
   insert(agent.subject, agent.selected_index, { line = "", status = "insert" } )
   for i = agent.selected_index, #agent.subject do
      agent:_updateEditAgent(i)
   end
end
```


#### RunReviewAgent:cancelInsertion\(\)

If the selected line is a blank "insert" line, remove it and set the
`was_inserting` flag\. Intended as an unconditional guard sent before any
attempted selection change, so we just do nothing if the selected premise
isn't in "insert" state\.

```lua
local remove = assert(table.remove)
function RunReviewAgent.cancelInsertion(agent)
   if agent:selectedPremise().status ~= "insert"
      -- Don't remove an "insert" premise if it's the very last one
      or #agent.subject == 1 then
         return
   end

   remove(agent.subject, agent.selected_index)
   -- Remove the *last* EditAgent iff there is one,
   -- then update the others to preserve bindings
   agent.edit_agents[#agent.subject + 1] = nil
   agent:bufferCommand("editAgentRemoved", #agent.subject + 1)
   for i = agent.selected_index, #agent.subject do
      agent:_updateEditAgent(i)
   end
   agent.was_inserting = true
end
```


#### RunReviewAgent:setSelectedState\(state\)

We need to perform additional bookkeeping to add or remove a blank line when
changing to/from insert status\.

```lua
function RunReviewAgent.setSelectedState(agent, state)
   local premise = agent:selectedPremise()
   if premise.status == state then return end
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
         state = premise.status == "keep" and "trash" or "keep"
         ReviewAgent.setSelectedState(agent, state)
      else
         agent:insertLine()
      end
   else
      -- Need to explicitly check here because we don't want to change another
      -- premise's status when canceling out of insertion. Setting the flag
      -- means the change will occur the *next* time tab is pressed
      if premise.status == "insert" then
         agent:cancelInsertion()
      else
         ReviewAgent.setSelectedState(agent, state)
      end
   end
end
```


#### RunReviewAgent:selectionChanged\(\)

Any selection change clears the `was_inserting` flag\. It may have been set
earlier in the same operation when pressing up/down with an "insert" premise
selected\-\-this is correct behavior, the only time the flag matters is when
repeatedly pressing \[Shift\-\]Tab\.

```lua
function RunReviewAgent.selectionChanged(agent)
   agent.was_inserting = false
   ReviewAgent.selectionChanged(agent)
end
```


#### RunReviewAgent:selectIndex\(i\), :select\{Next|Previous\}Wrap\(\)

Cancel/remove any "insert" premise before changing selection\. We guard against
any selection change, but in practice all selection changes right now go
through `:select{Next|Previous}Wrap`\-\-which is good, because
:cancelInsertion\(\) may shift part of the list by one, throwing off the meaning
of the index if it was computed first\. Thus we separately override
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


#### RunReviewAgent:editInsertedLine\(\)

Switch to editing a blank, newly\-inserted line/premise, iff there is one\.

```lua
function RunReviewAgent.editInsertedLine(agent)
   if agent:selectedPremise().status ~= "insert" then
      return false
   end
   agent :send { method = "pushMode", "edit_line"}
end
```


#### RunReviewAgent:cancelInsertEditing\(\)

Cancel out of editing the line\-to\-be\-inserted, leaving it in place\.

```lua
function RunReviewAgent.cancelInsertEditing(agent)
   agent:cancelInsertion()
   agent :send { to = "agents.edit", method = "clear" }
   agent :send { method = "popMode" }
end
```


#### RunReviewAgent:acceptInsertion\(\)

Accept the line in the edit buffer as a new premise\.

```lua
function RunReviewAgent.acceptInsertion(agent)
   local line = agent :send { to = "agents.edit", method = "contents" }
   if line:find("^%s*$") then
      agent:cancelInsertEditing()
      return
   end
   agent :send { to = "agents.edit", method = "clear" }
   local premise = agent:selectedPremise()
   premise.line = line
   -- Switch out the status without going through the usual channels
   -- so that we don't remove the newly-added premise in the process
   premise.status = "keep"
   agent:_updateEditAgent(agent.selected_index)
   agent:selectNextWrap()
   send { method = "popMode" }
end
```


### RunReviewAgent:evalAndResume\(\)

Finishes the review process, evaluating all non\-trashed lines\.

```lua
local Deque = require "deque:deque"
function RunReviewAgent.evalAndResume(agent)
   -- Clear out any insertion-in-progress
   agent:cancelInsertion()
   local to_run = Deque()
   for _, premise in ipairs(agent.subject) do
      if premise.status == "keep" then
         to_run:push(premise.line)
      end
   end
   agent :send { method = "rerun", to_run }
   agent :send { to = "agents.status", method = "update", "default" }
   agent :send { method = "pushMode", "nerf" }
end
```


```lua
return core.cluster.constructor(RunReviewAgent)
```

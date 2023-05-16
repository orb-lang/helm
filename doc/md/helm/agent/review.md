# ReviewAgent

Abstract base for agents that handle editing of something like a Runeither a run itself or a session\)\.

\(

#### imports

```lua
local core = require "qor:core"
local math = core.math
local assert = assert(core.fn.assertfmt)

local cluster = require "cluster:cluster"
local Agent = require "helm:agent/agent"

local EditAgent = require "helm:agent/edit"
local ResultsAgent = require "helm:agent/results"


local Round   = use "helm:round"
```


### ReviewAgent\(\)

```lua
local new, ReviewAgent = cluster.genus(Agent)

cluster.extendbuilder(new, function(_new, agent)
   agent.selected_index = 0
   agent.edit_agents = {}
   agent.results_agent = ResultsAgent()
   agent.was_inserting = false
   return agent
end)
```


### ReviewAgent:update\(riff\)

Configure the agent to display/edit the rounds in `riff`\. Note we defer to an
abstract `:setInitialSelection()` as empty\-riff behavior differs\.

```lua
function ReviewAgent.update(agent, run)
   agent.topic = run
   agent:setInitialSelection()
   agent:_updateResultsAgent()
   -- Update any EditAgents we have without creating any more
   for index in pairs(agent.edit_agents) do
      agent:_updateEditAgent(index)
   end
   agent:contentsChanged()
end
```


### ReviewAgent:\_updateEditAgent\(index\), :\_updateResultsAgent\(\)

Since we lazy\-create our subsidiary agents, it's worth a function wrapper to
update them if\-and\-only\-if they exist\.

```lua
function ReviewAgent._updateEditAgent(agent, index)
   local edit_agent = agent.edit_agents[index]
   if edit_agent then
      edit_agent:update(agent.topic[index]:getLine())
   end
end

function ReviewAgent._updateResultsAgent(agent)
   local results_agent = agent.results_agent
   if results_agent then
      local round = agent:selectedRound()
      local result = round and round:result()
      results_agent:update(result)
      -- #todo scroll offset of the Resbuf needs to be reset at this point
      -- we have some serious thinking to do about how changes are
      -- communicated to the buffer
   end
end
```


### Selection, scrolling, etc


#### ReviewAgent:selectionChanged\(\)

Notification that the selected item in the list has changed\. Update the
results display and scroll the selection into view\. Our displayed contents
change as well because of the selection highlight\.

Any selection change clears the `was_inserting` flag\. It may have been set
earlier in the same operation when pressing up/down with an "insert" round
selected\-\-this is correct behavior, the only time the flag matters is when
repeatedly pressing \[Shift\-\]Tab\.

```lua
function ReviewAgent.selectionChanged(agent)
   agent.was_inserting = false
   agent:_updateResultsAgent()
   agent:contentsChanged()
   agent:bufferCommand("ensureSelectedVisible")
end
```


#### ReviewAgent:selectIndex\(index\)

Select the round at `index` in the session for possible editing\.

\#todo
to leave an "insert" round hanging around unselected\. But this throws off the
meaning of the index, so really we should be more careful, and it's not clear
what the behavior should be\. Fortunately this method is never actually hit
directly, so it's not a problem right now\.

```lua
local clamp = assert(math.clamp)
function ReviewAgent.selectIndex(agent, index)
   agent:cancelInsertion()
   index = #agent.topic == 0
      and 0
      or clamp(index, 1, #agent.topic)
   if index ~= agent.selected_index then
      agent.selected_index = index
      agent:selectionChanged()
   end
end
```


#### ReviewAgent:selectNextWrap\(\), :selectPreviousWrap\(\)

Selects the next/previous round, wrapping around to the beginning/end if we're
at the end/beginning, respectively\. Cancel any pending insertion first so we
start from the right place when computing the new index to select\.

```lua
function ReviewAgent.selectNextWrap(agent)
   agent:cancelInsertion()
   local new_idx = agent.selected_index < #agent.topic
      and agent.selected_index + 1
      or 1
   return agent:selectIndex(new_idx)
end
function ReviewAgent.selectPreviousWrap(agent)
   agent:cancelInsertion()
   local new_idx = agent.selected_index > 1
      and agent.selected_index - 1
      or #agent.topic
   return agent:selectIndex(new_idx)
end
```


#### ReviewAgent:selectedRound\(\)

```lua
function ReviewAgent.selectedRound(agent)
   return agent.topic[agent.selected_index]
end
```


### Status editing and insertion


#### When to switch to "insert"

The rounds are expected to know their list of valid statuses, but there is a
complication, because "insert" is **not** a legal state for already\-existing
rounds\. It occupies a sort of "virtual" place in the list of valid statuses,
and attempting to switch to it inserts a **new** blank round \(for which insert
is the only valid status\), and leaving it removes that round, **without**
changing the state of the now\-re\-selected following round\. Doing this naively
would leave us stuck in a loop between "keep" and "insert" \(or "trash" andinsert" when cycling backwards\), so we also maintain a flag indicating
whether
" we just left "insert"\. If this is set and we **would** switch toinsert", we skip over it and go to whatever's next/previous in the order\.

"
We use a property insert\_after\_status to indicate where in the order we should
pretend "insert" exists\. The reverse\-toggle behavior must be computed on the
fly because the list of valid statuses is not static\.

```lua
ReviewAgent.insert_after_status = nil
```


#### ReviewAgent:\[reverse\]toggleSelectedState\(\)

Toggles the state of the selected round, cycling through the valid statuses\.

```lua
function ReviewAgent.toggleSelectedState(agent)
   local round = agent:selectedRound()
   if not agent.was_inserting
   and round.status() == agent.insert_after_status then
      agent:insertRound()
   elseif round.status() == "insert" then
      agent:cancelInsertion()
   else
      agent.was_inserting = false
      agent:selectedRound().status.next()
      agent:contentsChanged()
   end
end

function ReviewAgent.reverseToggleSelectedState(agent)
   local round = agent:selectedRound()
   if not agent.was_inserting
   and round.status:peekPrev() == agent.insert_after_status then
      agent:insertRound()
   elseif round.status() == "insert" then
      agent:cancelInsertion()
   else
      agent.was_inserting = false
      agent:selectedRound().status.prev()
      agent:contentsChanged()
   end
end
```


#### ReviewAgent:setSelectedState\(state\)

Directly set the state of the selected round\. If the requested status is not valid for the round,
do nothing\.

\#todo

```lua
function ReviewAgent.setSelectedState(agent, state)
   if agent:selectedRound().status.set(state) then
      agent:contentsChanged()
      return true
   else
      -- #todo Must not be valid at this time, should BEL here
      return false
   end
end
```


#### ReviewAgent:insertRound\(\)

Insert a blank round with "insert" status before the currently\-selected round,
thus selecting it\.

```lua
function ReviewAgent.insertRound(agent)
   -- #todo Need to use RiffRound or Premise as appropriate here
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


#### ReviewAgent:cancelInsertion\(\)

If the selected round is blank, with "insert" status, remove it and set the
`was_inserting` flag\. Intended as an unconditional guard sent before any
attempted selection change, so we just do nothing if the selected round
isn't in "insert" state\.

```lua
local remove = assert(table.remove)
function ReviewAgent.cancelInsertion(agent)
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


### Line editing


#### ReviewAgent:editLine\(\)

Begin editing the line of the selected round\.

```lua
function ReviewAgent.editLine(agent)
   local line = agent:selectedRound():getLine()
   agent :send { to = "agents.edit", method = "update", line }
   agent :send { method = "pushMode", "edit_line"}
end
```


#### ReviewAgent:cancelLineEdit\(\)

Cancel out of line editing, discarding changes\.

```lua
function ReviewAgent.cancelLineEdit(agent)
   agent:cancelInsertion()
   agent :send { to = "agents.edit", method = "clear" }
   agent :send { method = "popMode" }
end
```


#### ReviewAgent:acceptLineEdit\(\)

Accept the line in the edit buffer and update the selected round, changing it
from "insert" to "accept" if needed and moving to the next round\. An empty
string is not a valid/interesting line, so we either stay in "insert" state or
change to "trash" and the selection remains in place\.

```lua
function ReviewAgent.acceptLineEdit(agent)
   local line = agent :send { to = "agents.edit", method = "contents" }
   agent :send { to = "agents.edit", method = "clear" }
   local round = agent:selectedRound()
   round:setLine(line)
   if line:find("^%s*$") then
      -- Deleting the whole line is equivalent to trashing the round
      -- "Insert" rounds will ignore this as "trash" is not a valid state for them
      round.status:set("trash")
   else
      -- Switch out the status without going through the usual channels
      -- so that we don't remove the newly-added round in the process
      if round.status() == "insert" then
         round.status:set("keep")
      end
      agent:_updateEditAgent(agent.selected_index)
      agent:selectNextWrap()
   end
   agent :send { method = "popMode" }
end
```


### ReviewAgent:moveRound\{Up|Down\}\(\)

Moves the selected round up/back or down/forward in the riff\.

\#todo
For now, we assume the user knows what they're doing, and they can always
use `br session update` to fix things separately\.

```lua
local function _swap_rounds(agent, index_a, index_b)
   local round_a = agent.topic[index_a]
   local round_b = agent.topic[index_b]

   agent.topic[index_a] = round_b
   round_b.ordinal = index_a
   agent:_updateEditAgent(index_a)

   agent.topic[index_b] = round_a
   round_a.ordinal = index_b
   agent:_updateEditAgent(index_b)

   agent:contentsChanged()
end

function ReviewAgent.moveRoundUp(agent)
   if agent.selected_index == 1 then
      return false
   end
   _swap_rounds(agent, agent.selected_index, agent.selected_index - 1)
   -- Maintain selection of the same round after the move
   -- Will never wrap because we disallowed moving the first round up
   agent:selectPreviousWrap()
   return true
end

function ReviewAgent.moveRoundDown(agent)
   if agent.selected_index == #agent.topic then
      return false
   end
   _swap_rounds(agent, agent.selected_index, agent.selected_index + 1)
   agent:selectNextWrap()
   return true
end
```


## Buffer interaction protocol


### ReviewAgent:bufferValue\(\)

```lua
function ReviewAgent.bufferValue(agent)
   return agent.topic
end
```


### ReviewAgent:windowConfiguration\(\)

Our primary window exposes selection information, and can also retrieve
windows for our subsidiary `Edit` and `ResultsAgent`s\.

```lua
function ReviewAgent.windowConfiguration(agent)
   return agent.mergeWindowConfig(Agent.windowConfiguration(), {
      field = { selected_index = true },
      closure = { selectedRound = true,
                  editWindow = true,
                  resultsWindow = true }
   })
end
```


#### ReviewAgent:editWindow\(index\)

Retrieve the window for the EditAgent for the `index`th round\.

```lua
local inbounds = assert(math.inbounds)
local lua_thor = assert(require "helm:lex" . lua_thor)
function ReviewAgent.editWindow(agent, index)
   assert(inbounds(index, 1, #agent.topic))
   if not agent.edit_agents[index] then
      -- Stuff not-yet-initialized slots with `false`
      -- to maintain correct insert/remove/etc behavior
      for i = #agent.edit_agents + 1, index - 1 do
         agent.edit_agents[i] = false
      end
      agent.edit_agents[index] = EditAgent()
      agent.edit_agents[index].lex = lua_thor
      agent:_updateEditAgent(index)
   end
   return agent.edit_agents[index]:window()
end
```


#### ReviewAgent:resultsWindow\(\)

Retrieve the window to the ResultsAgent for the results of the
currently\-selected round\. This Agent and its Window is persistent, and is
updated when the selected round changes\.

```lua
function ReviewAgent.resultsWindow(agent)
   return agent.results_agent:window()
end
```


```lua
return new
```

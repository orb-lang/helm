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
```


### ReviewAgent\(\)

```lua
local new, ReviewAgent = cluster.genus(Agent)

cluster.extendbuilder(new, function(_new, agent)
   agent.selected_index = 0
   agent.edit_agents = {}
   agent.results_agent = ResultsAgent()
   agent.status_cycle_map = {}
   agent.status_reverse_map = {}
   local stats = _new.valid_statuses
   for i, this_status in ipairs(stats) do
      local prev_status = i == 1
         and stats[#stats]
         or stats[i - 1]
      local next_status = i == #stats
         and stats[1]
         or stats[i + 1]
      agent.status_cycle_map[this_status] = next_status
      agent.status_reverse_map[this_status] = prev_status
   end
   return agent
end)
```


### ReviewAgent:update\(run\)

Configure the agent to display/edit the premises in `run` \(which may be a Run
or Session for our respective specialist species\)\. Note we defer to an abstract
`:setInitialSelection()` as empty\-run behavior differs\.

```lua
function ReviewAgent.update(agent, run)
   agent.subject = run
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
      edit_agent:update(agent.subject[index].line)
   end
end

function ReviewAgent._updateResultsAgent(agent)
   local results_agent = agent.results_agent
   if results_agent then
      local premise = agent:selectedPremise()
      local result = premise and premise:result()
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

```lua
function ReviewAgent.selectionChanged(agent)
      agent:_updateResultsAgent()
      agent:contentsChanged()
      agent:bufferCommand("ensureSelectedVisible")
end
```


#### ReviewAgent:selectIndex\(index\)

Select the line at `index` in the session for possible editing\.

```lua
local clamp = assert(math.clamp)
function ReviewAgent.selectIndex(agent, index)
   index = #agent.subject == 0
      and 0
      or clamp(index, 1, #agent.subject)
   if index ~= agent.selected_index then
      agent.selected_index = index
      agent:selectionChanged()
   end
end
```


#### ReviewAgent:selectNextWrap\(\), :selectPreviousWrap\(\)

Selects the next/previous premise, wrapping around to the beginning/end
if we're at the end/beginning, respectively\.

```lua
function ReviewAgent.selectNextWrap(agent)
   local new_idx = agent.selected_index < #agent.subject
      and agent.selected_index + 1
      or 1
   return agent:selectIndex(new_idx)
end
function ReviewAgent.selectPreviousWrap(agent)
   local new_idx = agent.selected_index > 1
      and agent.selected_index - 1
      or #agent.subject
   return agent:selectIndex(new_idx)
end
```


#### ReviewAgent:selectedPremise\(\)

```lua
function ReviewAgent.selectedPremise(agent)
   return agent.subject[agent.selected_index]
end
```


### Editing


#### Status list and cycle maps

Concrete implementations must supply a list of possible premise/line statuses,
in the order they should cycle when pressing "tab"\.


#### ReviewAgent:\[reverse\]toggleSelectedState\(\)

Toggles the state of the selected line, cycling through the valid statuses\.

```lua
function ReviewAgent.toggleSelectedState(agent)
   local new_status = agent.status_cycle_map[agent:selectedPremise().status]
   return agent:setSelectedState(new_status)
end

function ReviewAgent.reverseToggleSelectedState(agent)
   local new_status = agent.status_reverse_map[agent:selectedPremise().status]
   return agent:setSelectedState(new_status)
end
```


#### ReviewAgent:setSelectedState\(state\)

Directly set the state of the selected line \(must be one of the valid states\)\.

```lua
function ReviewAgent.setSelectedState(agent, state)
   local premise = agent:selectedPremise()
   if premise.status == state then return end
   assert(agent.status_cycle_map[state], "Cannot change to invalid status %s", state)
   premise.status = state
   agent:contentsChanged()
   return true
end
```


#### ReviewAgent:movePremise\{Up|Down\}\(\)

Moves the selected premise up/back or down/forward in the session\.

\#todo
For now, we assume the user knows what they're doing, and they can always
use `br session update` to fix things separately\.

```lua
local function _swap_premises(agent, index_a, index_b)
   local premise_a = agent.subject[index_a]
   local premise_b = agent.subject[index_b]

   agent.subject[index_a] = premise_b
   premise_b.ordinal = index_a
   agent:_updateEditAgent(index_a)

   agent.subject[index_b] = premise_a
   premise_a.ordinal = index_b
   agent:_updateEditAgent(index_b)

   agent:contentsChanged()
end

function ReviewAgent.movePremiseUp(agent)
   if agent.selected_index == 1 then
      return false
   end
   _swap_premises(agent, agent.selected_index, agent.selected_index - 1)
   -- Maintain selection of the same premise after the move
   -- Will never wrap because we disallowed moving the first premise up
   agent:selectPreviousWrap()
   return true
end

function ReviewAgent.movePremiseDown(agent)
   if agent.selected_index == #agent.subject then
      return false
   end
   _swap_premises(agent, agent.selected_index, agent.selected_index + 1)
   agent:selectNextWrap()
   return true
end
```


## Buffer interaction protocol


### ReviewAgent:bufferValue\(\)

```lua
function ReviewAgent.bufferValue(agent)
   return agent.subject
end
```


### ReviewAgent:windowConfiguration\(\)

Our primary window exposes selection information, and can also retrieve
windows for our subsidiary `Edit` and `ResultsAgent`s\.

```lua
function ReviewAgent.windowConfiguration(agent)
   return agent.mergeWindowConfig(Agent.windowConfiguration(), {
      field = { selected_index = true },
      closure = { selectedPremise = true,
                  editWindow = true,
                  resultsWindow = true }
   })
end
```


#### ReviewAgent:editWindow\(index\)

Retrieve the window for the EditAgent for the `index`th premise\.

```lua
local inbounds = assert(math.inbounds)
local lua_thor = assert(require "helm:lex" . lua_thor)
function ReviewAgent.editWindow(agent, index)
   assert(inbounds(index, 1, #agent.subject))
   if not agent.edit_agents[index] then
      agent.edit_agents[index] = EditAgent()
      agent.edit_agents[index].lex = lua_thor
      agent:_updateEditAgent(index)
   end
   return agent.edit_agents[index]:window()
end
```


#### ReviewAgent:resultsWindow\(\)

Retrieve the window to the ResultsAgent for the results of the
currently\-selected premise\. This Agent and its Window is persistent, and is
updated when the selected premise changes\.

```lua
function ReviewAgent.resultsWindow(agent)
   return agent.results_agent:window()
end
```


```lua
return new
```
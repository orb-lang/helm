# SessionAgent

Agent responsible for editing/reviewing a session\.


#### imports

```lua
local meta = assert(require "core:cluster" . Meta)
local EditAgent = require "helm:agent/edit"
local ResultsAgent = require "helm:agent/results"
```


```lua
local Agent = require "helm:agent/agent"
local SessionAgent = meta(getmetatable(Agent))
```


### \_update\_edit\_agent\(index\), \_update\_results\_agent\(\)

Since we lazy\-create our subsidiary agents, it's worth a function wrapper to
update them if\-and\-only\-if they exist\.

```lua
local function _update_edit_agent(agent, index)
   local edit_agent = agent.edit_agents[index]
   if edit_agent then
      edit_agent:update(agent.session[index].line)
   end
end

local function _update_results_agent(agent)
   local results_agent = agent.results_agent
   if results_agent then
      local premise = agent:selectedPremise()
      local result = premise and (premise.new_result or premise.old_result)
      results_agent:update(result)
      -- #todo scroll offset of the Resbuf needs to be reset at this point
      -- we have some serious thinking to do about how changes are
      -- communicated to the buffer
   end
end
```


### SessionAgent:update\(sesh\)

```lua
function SessionAgent.update(agent, sesh)
   agent.session = sesh
   agent.selected_index = #sesh == 0 and 0 or 1
   _update_results_agent(agent)
   -- Update any EditAgents we have without creating any more
   for index in pairs(agent.edit_agents) do
      _update_edit_agent(agent, index)
   end
   agent:contentsChanged()
end
```


### Selection, scrolling, etc


#### SessionAgent:selectIndex\(index\)

Select the line at `index` in the session for possible editing\.

```lua
local clamp = assert(require "core:math" . clamp)
function SessionAgent.selectIndex(agent, index)
   index = #agent.session == 0
      and 0
      or clamp(index, 1, #agent.session)
   if index ~= agent.selected_index then
      agent.selected_index = index
      _update_results_agent(agent)
      agent:contentsChanged()
      agent:bufferCommand("ensureSelectedVisible")
      -- #todo can/should we be the ones to update the EditAgent
      -- for the title somehow? Send it a message...
   end
end
```


#### SessionAgent:selectNextWrap\(\), :selectPreviousWrap\(\)

Selects the next/previous premise, wrapping around to the beginning/end
if we're at the end/beginning, respectively\.

```lua
function SessionAgent.selectNextWrap(agent)
   local new_idx = agent.selected_index < #agent.session
      and agent.selected_index + 1
      or 1
   return agent:selectIndex(new_idx)
end
function SessionAgent.selectPreviousWrap(agent)
   local new_idx = agent.selected_index > 1
      and agent.selected_index - 1
      or #agent.session
   return agent:selectIndex(new_idx)
end
```


#### SessionAgent:selectedPremise\(\)

```lua
function SessionAgent.selectedPremise(agent)
   return agent.session[agent.selected_index]
end
```


#### SessionAgent:scrollResultsDown\(\), :scrollResultsUp\(\)

Scroll within the results area for the currently\-selected line\.

```lua
function SessionAgent.scrollResultsDown(agent)
   agent.results_agent:scrollDown()
end

function SessionAgent.scrollResultsUp(agent)
   agent.results_agent:scrollUp()
end
```


### Editing


#### SessionAgent:\[reverse\]toggleSelectedState\(\)

Toggles the state of the selected line, cycling through "accept", "reject",ignore", "skip"\.

"
```lua
local status_cycle_map = {
   ignore = "accept",
   accept = "reject",
   reject = "skip",
   skip   = "ignore"
}

function SessionAgent.toggleSelectedState(agent)
   local premise = agent:selectedPremise()
   premise.status = status_cycle_map[premise.status]
   agent:contentsChanged()
   return true
end

local inverse = assert(require "core:table" . inverse)
local status_reverse_map = inverse(status_cycle_map)

function SessionAgent.reverseToggleSelectedState(agent)
   local premise = agent:selectedPremise()
   premise.status = status_reverse_map[premise.status]
   agent:contentsChanged()
   return true
end
```


#### SessionAgent:movePremise\{Up|Down\}\(\)

Moves the selected premise up/back or down/forward in the session\.

\#todo
For now, we assume the user knows what they're doing, and they can always
use `br session update` to fix things separately\.

```lua
local function _swap_premises(agent, index_a, index_b)
   local premise_a = agent.session[index_a]
   local premise_b = agent.session[index_b]

   agent.session[index_a] = premise_b
   premise_b.ordinal = index_a
   _update_edit_agent(agent, index_a)

   agent.session[index_b] = premise_a
   premise_a.ordinal = index_b
   _update_edit_agent(agent, index_b)

   agent:contentsChanged()
end

function SessionAgent.movePremiseUp(agent)
   if agent.selected_index == 1 then
      return false
   end
   _swap_premises(agent, agent.selected_index, agent.selected_index - 1)
   -- Maintain selection of the same premise after the move
   -- Will never wrap because we disallowed moving the first premise up
   agent:selectPreviousWrap()
   return true
end

function SessionAgent.movePremiseDown(agent)
   if agent.selected_index == #agent.session then
      return false
   end
   _swap_premises(agent, agent.selected_index, agent.selected_index + 1)
   agent:selectNextWrap()
   return true
end
```


### SessionAgent:bufferValue\(\)

```lua
function SessionAgent.bufferValue(agent)
   return agent.session
end
```


### SessionAgent:windowConfiguration\(\)

Our primary window exposes selection information, and can also retrieve
windows for our subsidiary `Edit` and `ResultsAgent`s\.

```lua
function SessionAgent.windowConfiguration(agent)
   return agent.mergeWindowConfig(Agent.windowConfiguration(), {
      field = { selected_index = true },
      closure = { selectedPremise = true,
                  editWindow = true,
                  resultsWindow = true }
   })
end
```


#### SessionAgent:editWindow\(index\)

Retrieve the window for the EditAgent for the `index`th premise\.

```lua
local inbounds = assert(require "core:math" . inbounds)
local lua_thor = assert(require "helm:lex" . lua_thor)
function SessionAgent.editWindow(agent, index)
   assert(inbounds(index, 1, #agent.session))
   if not agent.edit_agents[index] then
      agent.edit_agents[index] = EditAgent()
      agent.edit_agents[index].lex = lua_thor
      _update_edit_agent(agent, index)
   end
   return agent.edit_agents[index]:window()
end
```


#### SessionAgent:resultsWindow\(\)

Retrieve the window to the ResultsAgent for the results of the
currently\-selected premise\. This Agent and its Window is persistent, and is
updated when the selected premise changes\.

```lua
function SessionAgent.resultsWindow(agent)
   if not agent.results_agent then
      agent.results_agent = ResultsAgent()
      _update_results_agent(agent)
   end
   return agent.results_agent:window()
end
```


### SessionAgent:\_init\(\)

```lua
function SessionAgent._init(agent)
   Agent._init(agent)
   agent.selected_index = 0
   agent.edit_agents = {}
end
```


```lua
local constructor = assert(require "core:cluster" . constructor)
return constructor(SessionAgent)
```

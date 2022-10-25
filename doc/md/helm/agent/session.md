# SessionAgent

Agent responsible for editing/reviewing a session\.


#### imports

```lua
local core = require "qor:core"
local math = core.math
local table = core.table

local cluster = require "cluster:cluster"
local ReviewAgent = require "helm:agent/review"
```


### SessionAgent\(\)

```lua
local new, SessionAgent = cluster.genus(ReviewAgent)
cluster.extendbuilder(new, true)
```


### SessionAgent:setInitialSelection\(\)

Sessions may be empty, start with the first premise selected iff there is one\.

```lua
local insert = assert(table.insert)
function SessionAgent.setInitialSelection(agent)
   agent.selected_index = #agent.topic == 0 and 0 or 1
end
```


### SessionAgent:selectIndex\(i\)

Transfer the newly\-selected premise title to the EditAgent after selection\.

```lua
function SessionAgent.selectIndex(agent, i)
   ReviewAgent.selectIndex(agent, i)
   local premise = agent:selectedPremise()
   agent :send { to = "agents.edit",
                 method = "update",
                 premise and premise.title }
end
```


### Editing


#### Status list

```lua
SessionAgent.valid_statuses = {
   "ignore", "accept", "reject", "trash"
}
```


#### Title editing


##### SessionAgent:editSelectedTitle\(\), :cancelTitleEditing\(\)

Switches in and out of special mode to edit the title of the selected premise\.

```lua
function SessionAgent.editSelectedTitle(agent)
   agent :send { method = "pushMode", "edit_title" }
end

function SessionAgent.cancelTitleEditing(agent)
   agent :send { method = "popMode" }
end
```


##### SessionAgent:acceptTitleUpdate\(\)

User is done editing a premise title, update it in the session data structure\.

```lua
function SessionAgent.acceptTitleUpdate(agent)
   local new_title = agent :send { to = "agents.edit", method = "contents" }
   agent:selectedPremise().title = new_title
   agent:selectNextWrap()
   agent:cancelTitleEditing()
end
```


### Prompt to save changes

```lua
function SessionAgent.promptSaveChanges(agent)
   local sesh_title = agent.topic.session_title
   agent :send { to = "agents.modal", method = "show",
      'Save changes to the session "' .. sesh_title .. '"?',
      "yes_no_cancel" }
end
```


```lua
return new
```

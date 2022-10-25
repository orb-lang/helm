







local core = require "qor:core"
local math = core.math
local table = core.table

local cluster = require "cluster:cluster"
local ReviewAgent = require "helm:agent/review"






local new, SessionAgent = cluster.genus(ReviewAgent)
cluster.extendbuilder(new, true)








local insert = assert(table.insert)
function SessionAgent.setInitialSelection(agent)
   agent.selected_index = #agent.topic == 0 and 0 or 1
end








function SessionAgent.selectIndex(agent, i)
   ReviewAgent.selectIndex(agent, i)
   local premise = agent:selectedPremise()
   agent :send { to = "agents.edit",
                 method = "update",
                 premise and premise.title }
end









SessionAgent.valid_statuses = {
   "ignore", "accept", "reject", "trash"
}











function SessionAgent.editSelectedTitle(agent)
   agent :send { method = "pushMode", "edit_title" }
end

function SessionAgent.cancelTitleEditing(agent)
   agent :send { method = "popMode" }
end








function SessionAgent.acceptTitleUpdate(agent)
   local new_title = agent :send { to = "agents.edit", method = "contents" }
   agent:selectedPremise().title = new_title
   agent:selectNextWrap()
   agent:cancelTitleEditing()
end






function SessionAgent.promptSaveChanges(agent)
   local sesh_title = agent.topic.session_title
   agent :send { to = "agents.modal", method = "show",
      'Save changes to the session "' .. sesh_title .. '"?',
      "yes_no_cancel" }
end




return new


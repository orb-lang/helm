







local table = core.table




local ReviewAgent = require "helm:agent/review"
local SessionAgent = meta(getmetatable(ReviewAgent))






function SessionAgent.update(agent, sesh)
   agent.subject = sesh
   agent.selected_index = #sesh == 0 and 0 or 1
   agent:_updateResultsAgent()
   -- Update any EditAgents we have without creating any more
   for index in pairs(agent.edit_agents) do
      agent:_updateEditAgent(index)
   end
   agent:contentsChanged()
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
   local sesh_title = agent.subject.session_title
   agent :send { to = "agents.modal", method = "show",
      'Save changes to the session "' .. sesh_title .. '"?',
      "yes_no_cancel" }
end




return core.cluster.constructor(SessionAgent)


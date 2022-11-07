







local core = require "qor:core"
local table = core.table

local cluster = require "cluster:cluster"
local ResultListAgent = require "helm:agent/result-list"






local new, SearchAgent = cluster.genus(ResultListAgent)
cluster.extendbuilder(new, true)








function SearchAgent.update(agent)
   local frag = agent :send { to = "agents.edit", method = "contents" }
   if agent.topic.lit_frag == frag then
      return
   end
   -- #todo most people would need to refer to 'modeS.hist' here,
   -- but this happens to be dispatched *by* modeS directly. Need
   -- more intelligent cooperation between modeS and Maestro
   agent.topic = agent :send { to = "hist", method = "search", frag }
   agent:contentsChanged()
end






function SearchAgent.acceptAtIndex(agent, selected_index)
   if agent:hasResults() then
      selected_index = selected_index or agent.topic.selected_index
      if selected_index == 0 then selected_index = 1 end
      local hist_index = agent.topic.cursors[selected_index]
      local line, result = agent :send { hist_index,
                                         to = "hist",
                                         method = "index",
                                         n = 1 }
      agent :send { to = "agents.edit", method = "update", line }
      agent :send { to = "agents.results", method = "update", result }
   end
   agent:quit()
end
-- If no argument is passed this happily falls through
SearchAgent.acceptSelected = SearchAgent.acceptAtIndex









function SearchAgent.activateOnFirstKey(agent)
   if agent :send { to = "agents.edit", method = "isEmpty" } then
      agent :send { method = "pushMode", "search" }
      return true
   else
      return false
   end
end






function SearchAgent.acceptFromNumberKey(agent, evt)
   local index = tonumber(evt.key)
   if index > #agent.topic then
      -- #todo maybe BEL here?
      return
   end
   agent:acceptAtIndex(index)
end








function SearchAgent.userCancel(agent)
   if agent:selectedItem() then
      agent:selectNone()
   else
      agent:quit()
   end
end










function SearchAgent.quitIfNoSearchTerm(agent)
   if agent :send { to = "agents.edit", method = "isEmpty" } then
      agent:quit()
      return true
   else
      return false
   end
end




return new


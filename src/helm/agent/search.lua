




local meta = assert(require "core:cluster" . Meta)
local ResultListAgent = require "helm:agent/result-list"
local SearchAgent = meta(getmetatable(ResultListAgent))








local function _set_suggestions(agent, suggestions)
   agent.last_collection = suggestions
   agent.touched = true
end


function SearchAgent.update(agent, modeS)
   local frag = agent.searchText()
   if agent.last_collection
      and agent.last_collection.lit_frag == frag then
      return
   end
   agent.last_collection = modeS.hist:search(frag)
   agent.touched = true
end






function SearchAgent.accept(agent)
   local suggestion = agent.last_collection:selectedItem()
   agent.replaceToken(suggestion)
   -- yield(Message{sendto = "maestro.agents.edit", method = "replaceToken", n = 1, suggestion})
end




local SearchAgent_class = setmetatable({}, SearchAgent)
SearchAgent.idEst = SearchAgent_class

return SearchAgent_class








local SearchAgent = meta {}
local new









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
end









local agent_utils = require "helm:agent/utils"

SearchAgent.checkTouched = assert(agent_utils.checkTouched)

local function _toLastCollection(agent, window, field, ...)
   local lc = agent.last_collection
   return lc and lc[field](lc, ...) -- i.e. lc:<field>(...)
end
SearchAgent.window = agent_utils.make_window_method({
   fn = {
      buffer_value = function(agent, window, field)
         return agent.last_collection
            and { n = 1, agent.last_collection }
      end
   },
   closure = {
      selectedItem = _toLastCollection,
      highlight = _toLastCollection
   }
})







new = function()
   local agent = meta(SearchAgent)
   return agent
end




SearchAgent.idEst = new
return new

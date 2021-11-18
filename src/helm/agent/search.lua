




local meta = assert(require "core:cluster" . Meta)
local ResultListAgent = require "helm:agent/result-list"
local SearchAgent = meta(getmetatable(ResultListAgent))






local yield = assert(coroutine.yield)
local clone = assert(require "core:table" . clone)








function SearchAgent.update(agent, modeS)
   local frag = agent:agentMessage("edit", "contents")
   if agent.last_collection
      and agent.last_collection.lit_frag == frag then
      return
   end
   agent.last_collection = modeS.hist:search(frag)
   agent:contentsChanged()
end






function SearchAgent.acceptAtIndex(agent, selected_index)
   local search_result = agent.last_collection
   local line, result
   if search_result and #search_result > 0 then
      selected_index = selected_index or search_result.selected_index
      if selected_index == 0 then selected_index = 1 end
      line, result = yield{ sendto = "hist",
                            method = "index",
                            n = 1,
                            search_result.cursors[selected_index] }
   end
   agent:quit()
   agent:agentMessage("edit", "update", line)
   agent:agentMessage("results", "update", result)
end
-- If no argument is passed this happily falls through
SearchAgent.acceptSelected = SearchAgent.acceptAtIndex









function SearchAgent.activateOnFirstKey(agent)
   if agent:agentMessage("edit", "isEmpty") then
      agent:shiftMode("search")
      return true
   else
      return false
   end
end






function SearchAgent.acceptFromNumberKey(agent, evt)
   agent:acceptAtIndex(tonumber(evt.key))
end








function SearchAgent.userCancel(agent)
   if agent:selectedItem() then
      agent:selectNone()
   else
      agent:quit()
   end
end










function SearchAgent.quitIfNoSearchTerm(agent)
   if agent:agentMessage("edit", "isEmpty") then
      agent:quit()
      return true
   else
      return false
   end
end






SearchAgent.keymap_try_activate = {
   ["/"] = "activateOnFirstKey"
}

SearchAgent.keymap_actions = clone(ResultListAgent.keymap_actions)
for i = 1, 9 do
   SearchAgent.keymap_actions["M-" .. tostring(i)] = "acceptFromNumberKey"
end
SearchAgent.keymap_actions.BACKSPACE = "quitIfNoSearchTerm"
SearchAgent.keymap_actions.DELETE = "quitIfNoSearchTerm"



local constructor = assert(require "core:cluster" . constructor)
return constructor(SearchAgent)


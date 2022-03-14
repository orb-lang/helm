# Search Agent

  An Agent providing history\-search functionality\.


#### imports

```lua
local table = core.table
```


```lua
local ResultListAgent = require "helm:agent/result-list"
local SearchAgent = meta(getmetatable(ResultListAgent))
```


### SearchAgent:update\(\)

Updates the history results based on the current contents of the Txtbuf\.

```lua
function SearchAgent.update(agent, modeS)
   local frag = agent :send { sendto = "agents.edit", method = "contents" }
   if agent.last_collection
      and agent.last_collection.lit_frag == frag then
      return
   end
   agent.last_collection = modeS.hist:search(frag)
   agent:contentsChanged()
end
```


### SearchAgent:acceptAtIndex\(index\), :acceptSelected\(\)

```lua
function SearchAgent.acceptAtIndex(agent, selected_index)
   local search_result = agent.last_collection
   if search_result and #search_result > 0 then
      selected_index = selected_index or search_result.selected_index
      if selected_index == 0 then selected_index = 1 end
      local idx = search_result.cursors[selected_index]
      local line, result = agent :send { idx,
                                         sendto = "hist",
                                         method = "index",
                                         n = 1 }
      agent :send { sendto = "agents.edit", method = "update", line }
      agent :send { sendto = "agents.results", method = "update", result }
   end
   agent:quit()
end
-- If no argument is passed this happily falls through
SearchAgent.acceptSelected = SearchAgent.acceptAtIndex
```


### Keymap and Event Handlers


#### SearchAgent:activateOnFirstKey\(\)

```lua
function SearchAgent.activateOnFirstKey(agent)
   if agent :send { sendto = "agents.edit", method = "isEmpty" } then
      agent :send { method = "shiftMode", "search" }
      return true
   else
      return false
   end
end
```


#### SearchAgent:acceptFromNumberKey\(evt\)

```lua
function SearchAgent.acceptFromNumberKey(agent, evt)
   agent:acceptAtIndex(tonumber(evt.key))
end
```


#### SearchAgent:userCancel\(\)

Deselect if anything is selected, or quit if nothing is\.

```lua
function SearchAgent.userCancel(agent)
   if agent:selectedItem() then
      agent:selectNone()
   else
      agent:quit()
   end
end
```


#### SearchAgent:quitIfNoSearchTerm\(\)

Quit if there is nothing in the search field, otherwise fall through\. Bound to
BACKSPACE and DELETE to exit search mode if they are pressed again after the
command zone is empty\.

```lua
function SearchAgent.quitIfNoSearchTerm(agent)
   if agent :send { sendto = "agents.edit", method = "isEmpty" } then
      agent:quit()
      return true
   else
      return false
   end
end
```


#### Keymaps

```lua
local addall = assert(table.addall)
SearchAgent.keymap_try_activate = {
   ["/"] = "activateOnFirstKey"
}

SearchAgent.keymap_actions = {
   BACKSPACE = "quitIfNoSearchTerm",
   DELETE = "quitIfNoSearchTerm"
}
for i = 1, 9 do
   SearchAgent.keymap_actions["M-" .. tostring(i)] = { method = "acceptFromNumberKey", n = 1 }
end
addall(SearchAgent.keymap_actions, ResultListAgent.keymap_actions)
```

```lua
return core.cluster.constructor(SearchAgent)
```

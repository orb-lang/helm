# Search Agent

  An Agent providing history\-search functionality\.

```lua
local meta = assert(require "core:cluster" . Meta)
local ResultListAgent = require "helm:agent/result-list"
local SearchAgent = meta(getmetatable(ResultListAgent))
```


#### imports

```lua
local yield = assert(coroutine.yield)
local clone = assert(require "core:table" . clone)
```


### SearchAgent:update\(\)

Updates the history results based on the current contents of the Txtbuf\.

```lua
function SearchAgent.update(agent, modeS)
   local frag = agent:agentMessage("edit", "contents")
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
```


### Keymap and Event Handlers


#### SearchAgent:activateOnFirstKey\(\)

```lua
function SearchAgent.activateOnFirstKey(agent)
   if agent:agentMessage("edit", "isEmpty") then
      agent:shiftMode("search")
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
   if agent:agentMessage("edit", "isEmpty") then
      agent:quit()
      return true
   else
      return false
   end
end
```


#### Keymaps

```lua
local addall = assert(require "core:table" . addall)
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
local constructor = assert(require "core:cluster" . constructor)
return constructor(SearchAgent)
```

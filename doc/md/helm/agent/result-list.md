# Result\-list Agent

An abstract Agent class implementing common behavior for Agents that manage a
list of results of some kind\.


#### imports

```lua
local SelectionList = require "helm:selection_list"
```


```lua
local meta = assert(require "core:cluster" . Meta)
local Agent = require "helm:agent/agent"
local ResultListAgent = meta(getmetatable(Agent))
```


### Selection methods

We wrap `select*` methods of `SelectionList` to also re\-render and make sure
the new selection is visible\.

```lua
for _, method_name in ipairs{"selectNext", "selectPrevious",
                    "selectNextWrap", "selectPreviousWrap",
                    "selectFirst", "selectIndex", "selectNone"} do
   ResultListAgent[method_name] = function(agent, ...)
      if agent.last_collection then
         agent.last_collection[method_name](agent.last_collection, ...)
         agent:contentsChanged()
         agent:bufferCommand("ensureVisible", agent.last_collection.selected_index)
      end
   end
end
```

It's also handy to have a nil\-safe way to retrieve what is currently selected\.

```lua
function ResultListAgent.selectedItem(agent)
   return agent.last_collection and agent.last_collection:selectedItem()
end
```


### ResultListAgent:quit\(\)

Quits the raga associated with the agent, returning to the default\.

```lua
function ResultListAgent.quit(agent)
   agent:selectNone()
   agent:shiftMode("default")
end
```


### ResultListAgent:bufferValue\(\)

```lua
function ResultListAgent.bufferValue(agent)
   return agent.last_collection and { n = 1, agent.last_collection }
end
```


### ResultListAgent:windowConfiguration\(\)

```lua
local function _toLastCollection(agent, window, field, ...)
   local lc = agent.last_collection
   return lc and lc[field](lc, ...) -- i.e. lc:<field>(...)
end

function ResultListAgent.windowConfiguration(agent)
   -- #todo super is hella broken, grab explicitly from the right superclass
   return agent.mergeWindowConfig(Agent.windowConfiguration(agent), {
      closure = {
         selectedItem = _toLastCollection,
         highlight = _toLastCollection
      }
   })
end
```


### Keymaps


- [ ]  \#Todo

  - [ ]  Add NAV\.SHIFT\_ALT\_\(UP|DOWN\), to move a page at a time\.
      Hook them to PgUp and PgDown while we're at it\.

  - [ ]  Add NAV\.HOME and NAV\.END to snap to the
      top and bottom\.

```lua
ResultListAgent.keymap_selection = {
   TAB = "selectNextWrap",
   DOWN = "selectNextWrap",
   ["S-DOWN"] = "selectNextWrap",
   ["S-TAB"] = "selectPreviousWrap",
   UP = "selectPreviousWrap",
   ["S-UP"] = "selectPreviousWrap"
}

-- These are both abstract methods
ResultListAgent.keymap_actions = {
   RETURN = "acceptSelected",
   ESC = "userCancel"
}
```


```lua
local constructor = assert(require "core:cluster" . constructor)
return constructor(ResultListAgent)
```

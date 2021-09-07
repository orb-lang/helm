# Edit premise title

A simple, single\-purpose raga for editing the title of a session premise\.
This is ugly and really should be able to be generalized, but without a
proper raga stack it's the best we can do\.


```lua
local clone    = import("core/table", "clone")
local EditBase = require "helm:helm/raga/edit"

local EditTitle = clone(EditBase, 2)
EditTitle.name = "edit_title"
EditTitle.prompt_char = "👉"
```


## NAV

```lua
local function _accept(modeS)
   local agents = modeS.maestro.agents
   agents.session:selectedPremise().title = agents.edit:contents()
   agents.session:selectNextWrap()
   modeS:shiftMode "review"
end

EditTitle.NAV.RETURN = _accept
EditTitle.NAV.TAB = _accept

function EditTitle.NAV.ESC(modeS, category, value)
   local agents = modeS.maestro.agents
   agents.edit:update(agents.session:selectedPremise().title)
   modeS:shiftMode "review"
end
```


## Quit handler

Quitting while editing a title still needs to prompt to save the session,
which we can handle by returning to review mode and retrying\.

```lua
EditTitle.CTRL["^Q"] = function(modeS, category, value)
   _accept(modeS)
   modeS.action_complete = false
end
```


## Ignored commands

"Restart" doesn't make sense for us

```lua
EditTitle.CTRL["^R"] = nil
```


```lua
return EditTitle
```
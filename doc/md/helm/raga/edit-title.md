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


## \_getSelectedPremise\(modeS\)

Retrieve the premise whose title we're editing\.
One of many ways in which this raga is an ugly hack\.

```lua
local function _getSelectedPremise(modeS)
   return modeS.zones.results.contents:selectedPremise()
end
```


## NAV

```lua
local function _accept(modeS)
   local sessionbuf = modeS.zones.results.contents
   sessionbuf:selectedPremise().title = modeS.maestro.agents.edit:contents()
   sessionbuf:selectNextWrap()
   modeS.shift_to = "review"
end

EditTitle.NAV.RETURN = _accept
EditTitle.NAV.TAB = _accept

function EditTitle.NAV.ESC(modeS, category, value)
   modeS.maestro.agents.edit:update(_getSelectedPremise(modeS).title)
   modeS.shift_to = "review"
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
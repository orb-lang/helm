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


## Insertion

Unlike most editing ragas, we don't clear the results zone when inserting text\.

```lua
function EditTitle.ASCII(modeS, category, value)
   modeS.txtbuf:insert(value)
end
EditTitle.UTF8 = EditTitle.ASCII

function EditTitle.PASTE(modeS, category, value)
   modeS.txtbuf:paste(value)
end
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
function EditTitle.NAV.RETURN(modeS, category, value)
   local sessionbuf = modeS.zones.results.contents
   sessionbuf:selectedPremise().title = tostring(modeS.txtbuf)
   sessionbuf:selectNextWrap()
   modeS.shift_to = "review"
end
EditTitle.NAV.TAB = EditTitle.NAV.RETURN

function EditTitle.NAV.ESC(modeS, category, value)
   modeS.txtbuf:replace(_getSelectedPremise(modeS).title)
   modeS.shift_to = "review"
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
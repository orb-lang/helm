# Edit premise title

A simple, single\-purpose raga for editing the title of a session premise\.
This is ugly and really should be able to be generalized, but without a
proper raga stack it's the best we can do\.


```lua
local core_table = require "core:table"
local addall, clone = assert(core_table.addall), assert(core_table.clone)
local EditBase = require "helm:helm/raga/edit"

local EditTitle = clone(EditBase, 2)
EditTitle.name = "edit_title"
EditTitle.prompt_char = "👉"
```


## Keymaps and event handlers

```lua
function EditTitle.accept()
   local title = send { sendto = "agents.edit", method = "contents" }
   send { sendto = "agents.session", method = "titleUpdated", title }
   EditTitle.quit()
end

function EditTitle.quit()
   send { method = "shiftMode", "review" }
end

EditTitle.keymap_extra_commands = {
   RETURN = "accept",
   TAB = "accept",
   ESC = "quit"
}
addall(EditTitle.keymap_extra_commands, EditBase.keymap_extra_commands)
```

"Restart" doesn't make sense for us, so remove it from the keymap\.

\#todo
shared between Vril and Nerf, but those could have an intermediate parent\.

```lua
EditTitle.keymap_extra_commands["C-r"] = nil
```


## Quit handler

Quitting while editing a title still needs to prompt to save the session,
which we can handle by returning to review mode and retrying\.

```lua
function EditTitle.quitHelm()
   EditTitle.accept()
   send { method = "tryAgain" }
end
```


```lua
return EditTitle
```
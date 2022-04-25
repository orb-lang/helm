# ModalAgent

Agent that powers our modal dialog\.

```lua
local Agent = require "helm:agent/agent"
local ModalAgent = meta(getmetatable(Agent))
```


## Dialog model

Basically just a holder for the text, button style, and result,
with an \_\_repr to generate the contents of the dialog\.

```lua
local DialogModel = meta {}

local concat, insert = assert(table.concat), assert(table.insert)
local ceil = assert(math.ceil)
local breakascii = assert(require "core:string/print" . breakascii)

local function _buttonTextFrom(button)
   local button_text = button.text
      :gsub('&([^&])', function(ch) return a.underline(ch) end, 1)
      :gsub('&&', '&')
   button_text = '[ ' .. button_text .. ' ]'
   if button.default then
      return a.bold(button_text)
   else
      return button_text
   end
end

local function _buttonWidthFrom(button)
   -- Four chars for the leading '[ ' and trailing ' ]'
   return 4 + #button.text:gsub('&(.)', '%1')
end

local function _buttonAndSpaceInfo(model)
   local buttons_width, spaces_count = 0, 0
   -- First, figure out how much space we need to fill
   for i, button in ipairs(model.buttons) do
      if button.text then
         buttons_width = buttons_width + _buttonWidthFrom(button)
         if i ~= 1 then
            -- For space between buttons
            buttons_width = buttons_width + 1
         end
      elseif button.space then
         spaces_count = spaces_count + 1
      end
   end
   return buttons_width, spaces_count
end

function DialogModel.__repr(model, window, c)
   local phrase = {}
   local wrapped_text = breakascii(model.text, 40)
   insert(phrase, wrapped_text)
   insert(phrase, "\n\n")
   local buttons_width, spaces_count = _buttonAndSpaceInfo(model)
   local space_remaining = window.width - buttons_width
   for i, button in ipairs(model.buttons) do
      if button.text then
         if i ~= 1 then insert(phrase, " ") end
         insert(phrase, _buttonTextFrom(button))
      elseif button.space then
         local spaces = ceil(space_remaining / spaces_count)
         insert(phrase, (" "):rep(spaces))
         space_remaining = space_remaining - spaces
         spaces_count = spaces_count - 1
      end
   end
   return concat(phrase)
end
```


### DialogModel:requiredExtent\(\)

Computes the extent required to display the modal\.

```lua
local max = assert(math.max)
local Point = require "anterm:point"

function DialogModel.requiredExtent(model)
   local _, text_height, text_width = breakascii(model.text, 40)
   local buttons_width, spaces_count = _buttonAndSpaceInfo(model)
   -- Ensure that any flexible-space element is at least one space wide
   local button_row_width = buttons_width + spaces_count
   -- Add two lines for a blank line and the button row
   return Point(text_height + 2, max(text_width, button_row_width))
end
```


### ModalAgent:update\(text, button\_style\)

Prepares to display a modal with the given text and button style,
which may be either a table or a shorthand name from the table below\.

```lua
local button_styles = {
   yes_no_cancel = {
      { value = "cancel", text = "&Cancel", cancel = true },
      { space = true },
      { value = "no", text = "&No" },
      { value = "yes", text = "&Yes", default = true }
   }
}

function ModalAgent.update(agent, text, button_style)
   local model = setmetatable({}, DialogModel)
   model.text = text
   if type(button_style) == "string" then
      button_style = button_styles[button_style]
   end
   model.buttons = button_style
   agent.subject = model
   agent:contentsChanged()
end
```


### ModalAgent:show\(text, button\_style\)

As :update\(\), but also shows the modal\.

```lua
function ModalAgent.show(agent, ...)
   agent:update(...)
   agent :send { method = "shiftMode", "modal" }
end
```


### ModalAgent:close\(answer\)

Closes the modal, storing the provided `answer` in the model\.

```lua
function ModalAgent.close(agent, value)
   agent.subject.value = value
   -- #todo shift back to the previous raga--modeS needs to maintain a stack
   agent :send { method = "shiftMode", "default" }
end
```


### ModalAgent:answer\(\)

Retrieves the value answered by the current/most\-recent modal dialog\.

```lua
function ModalAgent.answer(agent)
   return agent.subject and agent.subject.value
end
```


### ModalAgent:bufferValue\(\)

```lua
function ModalAgent.bufferValue(agent)
   return agent.subject and { n = 1, agent.subject } or { n = 0 }
end
```


### Keyboard input

```lua
local function _shortcutFrom(button)
   local shortcut_decl = button.text and button.text:match('&([^&])')
   return shortcut_decl and shortcut_decl:lower()
end

local function _acceptButtonWhere(agent, fn)
   for _, button in ipairs(agent.subject.buttons) do
      if fn(button) then
         return agent:close(button.value)
      end
   end
end

function ModalAgent.letterShortcut(agent, event)
   local key = event.key:lower()
   return _acceptButtonWhere(agent, function(button)
      return _shortcutFrom(button) == key
   end)
end

function ModalAgent.cancel(agent)
   return _acceptButtonWhere(agent, function(button) return button.cancel end)
end

function ModalAgent.acceptDefault(agent, event)
   return _acceptButtonWhere(agent, function(button) return button.default end)
end
```

```lua
return core.cluster.constructor(ModalAgent)
```

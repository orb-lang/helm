# ModalAgent

Agent that powers our modal dialog.

```lua
local ModalAgent = meta {}
```
## Dialog model

Basically just a holder for the text, button style, and result,
with an __repr to generate the contents of the dialog.

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
### DialogModel:requiredExtent()

Computes the extent required to display the modal.

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
### ModalAgent:update(text, button_style)

Prepares to display a modal with the given text and button style,
which may be either a table or a shorthand name from the table below.

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
   local model = meta(DialogModel)
   model.text = text
   if type(button_style) == "string" then
      button_style = button_styles[button_style]
   end
   model.buttons = button_style
   agent.model = model
   agent.touched = true
end
```
### ModalAgent:answer()

Retrieves the value answered by the current/most-recent modal dialog.

```lua
function ModalAgent.answer(agent)
   return agent.model and agent.model.value
end
```
### Window

```lua
local agent_utils = require "helm:agent/utils"

ModalAgent.checkTouched = agent_utils.checkTouched

ModalAgent.window = agent_utils.make_window_method({
   fn = {
      buffer_value = function(agent, window, field)
         return agent.model and { n = 1, agent.model } or { n = 0 }
      end
   }
})
```
### new

```lua
local function new()
   return meta(ModalAgent)
end
```
```lua
ModalAgent.idEst = new
return new
```

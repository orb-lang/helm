# Modal dialog

Raga for displaying a modal dialog\. Uses a small z=2 zone to display\.

```lua

local clone = assert(require 'core:table' . clone)
local a = require "anterm:anterm"
local RagaBase = require "helm:raga/base"
```

```lua
local Modal = clone(RagaBase, 2)
Modal.name = "modal"
Modal.prompt_char = " "
```

```lua
local function _getModel(modeS)
   return modeS.zones.modal.contents[1]
end

function Modal.close(modeS, value)
   _getModel(modeS).value = value
   -- #todo shift back to the previous raga--modeS needs to maintain a stack
   modeS.shift_to = modeS.raga_default
end
```

### Keyboard input

```lua
local function _shortcutFrom(button)
   local shortcut_decl = button.text and button.text:match('&([^&])')
   return shortcut_decl and shortcut_decl:lower()
end

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

function Modal.ASCII(modeS, category, value)
   local model = _getModel(modeS)
   local key = value:lower()
   for _, button in ipairs(model.buttons) do
      if _shortcutFrom(button) == key then
         return Modal.close(modeS, button.value)
      end
   end
   return RagaBase(modeS, category, value)
end

function Modal.NAV.ESC(modeS, category, value)
   local model = _getModel(modeS)
   for _, button in ipairs(model.buttons) do
      if button.cancel then
         return Modal.close(modeS, button.value)
      end
   end
end

function Modal.NAV.RETURN(modeS, category, value)
   local model = _getModel(modeS)
   for _, button in ipairs(model.buttons) do
      if button.default then
         return Modal.close(modeS, button.value)
      end
   end
end
```

### Modal\.onShift, \.onUnshift

```lua
function Modal.onShift(modeS)
   modeS.zones.modal:show()
end

function Modal.onUnshift(modeS)
   modeS.zones.modal:hide()
end
```

## Dialog model

Basically just a holder for the text, button style, and result,
with an \_\_repr to generate the contents of the dialog\.

```lua
local DialogModel = meta {}

local concat, insert = assert(table.concat), assert(table.insert)
local ceil = assert(math.ceil)
function DialogModel.__repr(model, window, c)
   local phrase = {}
   insert(phrase, model.text)
   insert(phrase, "\n\n\n")
   local buttons_width = 0
   local spaces_count = 0
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

local button_styles = {
   yes_no_cancel = {
      { value = "cancel", text = "&Cancel", cancel = true },
      { space = true },
      { value = "no", text = "&No" },
      { value = "yes", text = "&Yes", default = true }
   }
}

function Modal.newModel(text, button_style)
   local model = meta(DialogModel)
   model.text = text
   if type(button_style) == "string" then
      button_style = button_styles[button_style]
   end
   model.buttons = button_style
   return model
end
```

```lua
return Modal
```
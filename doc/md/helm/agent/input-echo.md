# Input\-echo Agent

A simple Agent providing echo\-display of input events\.


```lua
local c = assert(require "singletons:color" . color)
local input_event = require "anterm:input-event"

local InputEchoAgent = meta {}

```


### \_\_repr for input events

```lua
local STAT_ICON = "◉ "

local reprs_by_type = {}

function reprs_by_type.mouse(event)
   local subtype
   if event.pressed then
      if event.moving then
         subtype = "drag"
      else
         subtype = "press"
      end
   else
      if event.moving then
         subtype = "move"
      else
         subtype = "release"
      end
   end
   return ('%s (%s: %s,%s)'):format(
      c.userdata(STAT_ICON .. input_event.serialize(event)),
      subtype,
      a.cyan(event.col),
      a.cyan(event.row))
end

function reprs_by_type.paste(event)
   local result
   -- #todo handle escaping of special characters in pasted data
   if #event.text < 20 then
      result = "PASTE: " .. event.text
   else
      result = ("PASTE(%d): %s..."):format(#event.text, event.text:sub(1, 17))
   end
   return a.green(STAT_ICON .. result)
end

function reprs_by_type.keypress(event)
   local color = a.green
   if event.command == "NYI" then
      color = a.red
   -- #todo this is a mostly-accurate but terrible way to distinguish named keys
   -- We will have problems with UTF-8 if nothing else, and...just no
   elseif #event.key > 1 then
      color = a.magenta
   elseif event.modifiers ~= 0 then
      color = a.blue
   end
   return color(STAT_ICON .. input_event.serialize(event))
end

local echo_M = {}
function echo_M.__repr(event)
   local event_str = reprs_by_type[event.type](event)
   if event.command then
      event_str = event_str .. ': ' .. event.command
   end
   return event_str
end
```


### InputEchoAgent:update\(event, command\)

```lua
local clone = assert(require "core:table" . clone)
function InputEchoAgent.update(echo, event, command)
   echo.last_event = clone(event)
   echo.last_event.command = command
   setmetatable(echo.last_event, echo_M)
   echo.touched = true
end
```

### Window

```lua
local agent_utils = require "helm:agent/utils"
InputEchoAgent.checkTouched = assert(agent_utils.checkTouched)

local Window = require "window:window"
InputEchoAgent.window = agent_utils.make_window_method({
   fn = { buffer_value = function(echo)
      return echo.last_event and { n = 1, echo.last_event }
   end }
})
```

### new

```lua
local function new()
   return meta(InputEchoAgent)
end
```

```lua
InputEchoAgent.idEst = new
return new
```
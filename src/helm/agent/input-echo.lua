





local c = assert(require "singletons:color" . color)
local input_event = require "anterm:input-event"

local InputEchoAgent = meta {}







local STAT_ICON = "◉ "

local reprs_by_type = {}

function reprs_by_type.mouse(event)
   local subtype
   if event.scrolling then
      subtype = tostring(event.num_lines) .. " lines"
   else
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






local clone = assert(require "core:table" . clone)
function InputEchoAgent.update(echo, event, command)
   echo.last_event = clone(event)
   echo.last_event.command = command
   setmetatable(echo.last_event, echo_M)
   echo.touched = true
end





local agent_utils = require "helm:agent/utils"
InputEchoAgent.checkTouched = assert(agent_utils.checkTouched)

local Window = require "window:window"
InputEchoAgent.window = agent_utils.make_window_method({
   fn = { buffer_value = function(echo)
      return { n = 1, echo.last_event }
   end }
})





local function new()
   return meta(InputEchoAgent)
end



InputEchoAgent.idEst = new
return new


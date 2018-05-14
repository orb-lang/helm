 
color.orb* Color

```lua
local a = require "src/anterm"

local C = {}
C.color = {}
C.color.number = a.fg(42)
C.color.string = a.fg(222)
C.color.table  = a.fg(64)
C.color.func   = a.fg24(210,12,120)
C.color.truth  = a.fg(231)
C.color.falsehood  = a.fg(94)
C.color.nilness   = a.fg(93)
C.color.field  = a.fg(111)

C.color.alert = a.fg24(250, 0, 40)

```
## ts(value)

This is rapidly becoming something I'll move to core.


Some other part of core.

```lua
local hints = { field = C.color.field,
                  fn  = C.color.func }

local anti_G = {}

for k, v in pairs(_G) do
   anti_G [v] = k
end

function C.ts(value, hint)
   local c = C.color
   local str = tostring(value)
   if hint == "" then
      return str -- or just use tostring()?
   end
   if hint then
      return hints[hint](str)
   end

   local typica = type(value)
   if typica == 'number' then
      str = c.number(str)
   elseif typica == 'table' then
      str = c.table(str)
   elseif typica == 'function' then
      if anti_G[value] then
         -- we have a global name for this function
         str = c.func(anti_G[value])
      else
         local func_handle = "func:" .. string.sub(str, -6)
         str = c.func(func_handle)
      end
   elseif typica == 'boolean' then
      str = value and c.truth(str) or c.falsehood(str)
   elseif typica == 'string' then
      str = c.string(str)
   elseif typica == 'nil' then
      str = c.nilness(str)
   end
   return str
end
```
```lua
return C
```

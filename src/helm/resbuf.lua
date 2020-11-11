








assert (meta)
assert (ipairs)
local color = require "singletons/color"



local Resbuf = meta {}

function Resbuf.ts(resbuf)
   local res_map = {}
   if resbuf.frozen then
      for i, v in ipairs(resbuf) do
         res_map[i] = v
      end
   else
      for i, v in ipairs(resbuf) do
         res_map[i] = color.ts(v)
      end
   end

   return res_map
end

local function new(results, frozen)
   local resbuf = meta(Resbuf)
   if frozen then resbuf.frozen = true end
   for k, v in pairs(results) do
      resbuf[k] = v
   end
   return resbuf
end


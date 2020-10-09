

























local L        = require "lpeg"
local P, match = L.P, L.match
local Codepoints = require "singletons/codepoints"

local function fuzz_patt(frag)
   frag = type(frag) == "string" and Codepoints(frag) or frag
   local patt = P(true)
   for i = 1 , #frag do
      local v = frag[i]
      patt = patt * (P(1) - P(v))^0 * P(v)
   end
   return patt
end

return fuzz_patt


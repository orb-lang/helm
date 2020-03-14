












local L        = require "lpeg"
local P, match = L.P, L.match
local Codepoints = require "singletons/codepoints"

local function fuzz_patt(frag)
   frag = type(frag) == "string" and Codepoints(frag) or frag
   local patt =  (P(1) - P(frag[1]))^0
   for i = 1 , #frag - 1 do
      local v = frag[i]
      patt = patt * (P(v) * (P(1) - P(frag[i + 1]))^0)
   end
   patt = patt * P(frag[#frag])
   return patt
end

return fuzz_patt

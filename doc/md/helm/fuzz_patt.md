# fuzz\_patt

Builds an `lpeg` pattern which will recognize strings containing the characters
of `frag`, in order but allowing other characters in between\.

`(P(1) - P(frag[n]))^0` matches anything that isn't the next fragment,
including `""`\.  We then require this to be followed by the next fragment,
and so on\.

Exists as its own module for now because it's needed by history search and
`suggest`\. There's probably a better place to put it\.

```lua
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
```

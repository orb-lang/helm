






local a         = require "anterm:anterm"

local concat         = assert(table.concat)
local sub, gsub, rep = assert(string.sub),
                       assert(string.gsub),
                       assert(string.rep)







local RagaBase_meta = {}
local RagaBase = setmetatable({}, RagaBase_meta)

for _, cat in ipairs{"NAV", "CTRL", "ALT", "ASCII",
                     "UTF8", "PASTE", "MOUSE", "NYI"} do
   RagaBase[cat] = {}
end


















local hasfield, iscallable = import("core/table", "hasfield", "iscallable")

function RagaBase_meta.__call(raga, modeS, category, value)
   -- Dispatch on value if possible
   if hasfield(raga[category], value) then
      raga[category][value](modeS, category, value)
   -- Or on category if the whole category is callable
   elseif iscallable(raga[category]) then
      raga[category](modeS, category, value)
   -- Otherwise indicate that we didn't know what to do with the input
   else
      return false
   end
   return true
end










function RagaBase.onTxtbufChanged(modeS)
   return
end









function RagaBase.onCursorChanged(modeS)
   return
end








function RagaBase.onShift(modeS)
   return
end







function RagaBase.onUnshift(modeS)
   return
end



return RagaBase

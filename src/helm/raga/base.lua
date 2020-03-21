






local a         = require "anterm:anterm"

local concat         = assert(table.concat)
local sub, gsub, rep = assert(string.sub),
                       assert(string.gsub),
                       assert(string.rep)







local RagaBase = meta {}

for _, cat in ipairs{"NAV", "CTRL", "ALT", "ASCII",
                     "UTF8", "PASTE", "MOUSE", "NYI"} do
   RagaBase[cat] = {}
end












local hasfield, iscallable = import("core/table", "hasfield", "iscallable")

function RagaBase.__call(modeS, category, value)
   -- Dispatch on value if possible
   if hasfield(modeS.raga[category], value) then
      modeS.raga[category][value](modeS, category, value)
   -- Or on category if the whole category is callable
   elseif iscallable(modeS.raga[category]) then
      modeS.raga[category](modeS, category, value)
   -- Otherwise indicate that we didn't know what to do with the input
   else
      return false
   end
   return true
end










function RagaBase.txtbufChanged(modeS)
end









function RagaBase.cursorChanged(modeS)
end



return RagaBase

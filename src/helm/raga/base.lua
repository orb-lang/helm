







local a         = require "anterm:anterm"

local concat         = assert(table.concat)
local sub, gsub, rep = assert(string.sub),
                       assert(string.gsub),
                       assert(string.rep)



local RagaBase_meta = {}
local RagaBase = setmetatable({}, RagaBase_meta)

















function RagaBase.getCursorPosition(modeS)
   return nil
end











function RagaBase.onTxtbufChanged()
   return
end










function RagaBase.onCursorChanged()
   return
end









function RagaBase.onShift(modeS)
   return
end








function RagaBase.onUnshift(modeS)
   return
end




return RagaBase










local a         = require "anterm:anterm"

local concat         = assert(table.concat)
local sub, gsub, rep = assert(string.sub),
                       assert(string.gsub),
                       assert(string.rep)



local RagaBase_meta = {}
local RagaBase = setmetatable({}, RagaBase_meta)

















function RagaBase.getCursorPosition()
   return nil
end











function RagaBase.onTxtbufChanged()
   return
end










function RagaBase.onCursorChanged()
   return
end









function RagaBase.onShift()
   return
end








function RagaBase.onUnshift()
   return
end




return RagaBase


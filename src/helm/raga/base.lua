







local core = require "qor:core"

local concat         = assert(table.concat)
local sub, gsub, rep = assert(string.sub),
                       assert(string.gsub),
                       assert(string.rep)



local RagaBase_meta = {}
local RagaBase = setmetatable({}, RagaBase_meta)






RagaBase.name        = nil                       -- e.g. "nerf"
RagaBase.prompt_char = nil                       -- e.g. "$"
RagaBase.keymap      = nil                       -- e.g. require "helm:keymap/raga_name"
RagaBase.target      = nil                       -- `msg.to` path string, e.g. "agents.edit"
RagaBase.lex         = require "helm:lex" . null -- Lexer to use for the command zone














do
   local Message = require "actor:message"
   local nest = core.thread.nest "actor"
   local yield = assert(nest.yield)

   function RagaBase.send(tab)
      return yield(Message(tab))
   end
end










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


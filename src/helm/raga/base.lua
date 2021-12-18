







local a         = require "anterm:anterm"

local concat         = assert(table.concat)
local sub, gsub, rep = assert(string.sub),
                       assert(string.gsub),
                       assert(string.rep)
local yield = assert(coroutine.yield)



local RagaBase_meta = {}
local RagaBase = setmetatable({}, RagaBase_meta)























function RagaBase.agentMessage(agent_name, method_name, ...)
   local messages = _Bridge.messages
   if not messages then
      messages = {}
      _Bridge.messages = messages
   end
   local msg = pack(...)
   msg.method = method_name
   msg = { method = 'agent', n = 1, agent_name, message = msg }
   messages[#messages + 1] = msg
   return yield(msg)
end









function RagaBase.shiftMode(raga_name)
   return yield{ method = "shiftMode", n = 1, raga_name }
end










RagaBase.default_keymaps = {
   { source = "modeS.raga", name = "keymap_extra_commands" }
}









function RagaBase.quitHelm()
   -- #todo it's obviously terrible to have code specific to a particular
   -- piece of functionality in an abstract class like this.
   -- To do this right, we probably need a proper raga stack. Then -n could
   -- push the Review raga onto the bottom of the stack, then Nerf. Quit
   -- at this point would be the result of the raga stack being empty,
   -- rather than an explicitly-invoked command, and Ctrl-Q would just pop
   -- the current raga. Though, a Ctrl-Q from e.g. Search would still want
   -- to actually quit, so it's not quite that simple...
   -- Anyway. Also, don't bother saving the session if it has no premises...
   if _Bridge.args.new_session then
      local session = yield{ sendto = "hist", property = "session" }
      if #session > 0 then
         -- #todo Add the ability to change accepted status of
         -- the whole session to the review interface
         session.accepted = true
         -- Also, it's horribly hacky to change the "default" raga, but it's
         -- the only way to make Modal work properly. A proper raga stack
         -- would *definitely* fix this
         yield{ method = "setDefaultMode", n = 1, "review" }
         RagaBase.shiftMode "review"
         return
      end
   end
   yield{ method = "quit" }
end

RagaBase.keymap_extra_commands = {
   ["C-q"] = "quitHelm"
}










function RagaBase.getCursorPosition(modeS)
   return nil
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


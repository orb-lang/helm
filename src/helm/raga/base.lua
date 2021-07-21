







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
















RagaBase.CTRL["^Q"] = function(modeS, category, value)
   -- #todo it's obviously terrible to have code specific to a particular
   -- piece of functionality in an abstract class like this.
   -- To do this right, we probably need a proper raga stack. Then -n could
   -- push the Review raga onto the bottom of the stack, then Nerf. Quit
   -- at this point would be the result of the raga stack being empty,
   -- rather than an explicitly-invoked command, and Ctrl-Q would just pop
   -- the current raga. Though, a Ctrl-Q from e.g. Search would still want
   -- to actually quit, so it's not quite that simple...
   -- Anyway. Also, don't bother saving the session if it has no premises...
   if _Bridge.args.new_session and #modeS.hist.session > 0 then
      -- #todo Add the ability to change accepted status of
      -- the whole session to the review interface
      modeS.hist.session.accepted = true
      -- Also, it's horribly hacky to change the "default" raga, but it's
      -- the only way to make Modal work properly. A proper raga stack
      -- would *definitely* fix this
      modeS.raga_default = "review"
      modeS.shift_to = "review"
      modeS.maestro.agents.session:selectIndex(1)
      modeS:setStatusLine("review", modeS.hist.session.session_title)
   else
      modeS:quit()
   end
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


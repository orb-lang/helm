









local clone = import("core/table", "clone")
local RagaBase = require "helm:helm/raga/base"






local Page = clone(RagaBase, 2)

Page.name = "page"
Page.prompt_char = "❓"

local alias = require "helm/raga/aliaser" (Page)
















local function toZone(fn)
   return function(modeS, category, value)
      return modeS.zones.popup[fn](modeS.zones.popup)
   end
end










alias{ toZone "scrollDown",
       NAV   = {"DOWN", "SHIFT_DOWN", "RETURN"},
       ASCII = {"e", "j"},
       CTRL  = {"^N", "^E", "^J"} }

alias{ toZone "scrollUp",
       NAV   = {"UP", "SHIFT_UP", "SHIFT_RETURN"},
       ASCII = {"y", "k"},
       CTRL  = {"^Y", "^P", "^K"} }

alias{ toZone "pageDown",
       NAV   = {"PAGE_DOWN"},
       ASCII = {" ", "f"},
       CTRL  = {"^V", "^F"} }
alias{ toZone "pageUp",
       NAV   = {"PAGE_UP"},
       ASCII = {"b"},
       CTRL  = {"^B"} }

alias{ toZone "halfPageDown",
       ASCII = {"d"},
       CTRL  = {"^D"} }
alias{ toZone "halfPageUp",
       ASCII = {"u"},
       CTRL  = {"^U"} }

alias{ toZone "scrollToTop",
       NAV   = {"HOME"},
       ASCII = {"g", "<"} }
alias{ toZone "scrollToBottom",
       NAV   = {"END"},
       ASCII = {"G", ">"} }







local function _quit(modeS)
   -- #todo should have a stack of ragas and switch back to the one
   -- we entered from, but this will do for now
   modeS.shift_to = "nerf"
end

alias{_quit, NAV = {"ESC"}, ASCII = {"q"} }










function Page.MOUSE(modeS, category, value)
   if value.scrolling then
      if value.button == "MB0" then
         modeS.zones.popup:scrollUp()
      elseif value.button == "MB1" then
         modeS.zones.popup:scrollDown()
      end
   end
end
















function Page.onShift(modeS)
   modeS.zones.popup:show()
end
function Page.onUnshift(modeS)
   modeS.zones.popup:hide()
end






return Page







local clone = import("core/table", "clone")
local RagaBase = require "helm:helm/raga/base"



local Page = clone(RagaBase, 2)

Page.name = "page"
Page.prompt_char = "❓"

local alias = require "helm/raga/aliaser" (Page)








local function toRainbuf(fn)
   return function(modeS, category, value)
      local rainbuf = modeS.zones.popup.contents
      return rainbuf[fn](rainbuf)
   end
end





alias{ toRainbuf "scrollDown",
       NAV   = {"DOWN", "SHIFT_DOWN", "RETURN"},
       ASCII = {"e", "j"},
       CTRL  = {"^N", "^E", "^J"} }

alias{ toRainbuf "scrollUp",
       NAV   = {"UP", "SHIFT_UP", "SHIFT_RETURN"},
       ASCII = {"y", "k"},
       CTRL  = {"^Y", "^P", "^K"} }

alias{ toRainbuf "pageDown",
       NAV   = {"PAGE_DOWN"},
       ASCII = {" ", "f"},
       CTRL  = {"^V", "^F"} }
alias{ toRainbuf "pageUp",
       NAV   = {"PAGE_UP"},
       ASCII = {"b"},
       CTRL  = {"^B"} }

alias{ toRainbuf "halfPageDown",
       ASCII = {"d"},
       CTRL  = {"^D"} }
alias{ toRainbuf "halfPageUp",
       ASCII = {"u"},
       CTRL  = {"^U"} }

alias{ toRainbuf "scrollToTop",
       NAV   = {"HOME"},
       ASCII = {"g", "<"} }
alias{ toRainbuf "scrollToBottom",
       NAV   = {"END"},
       ASCII = {"G", ">"} }




local function _quit(modeS)
   -- #todo should have a stack of ragas and switch back to the one
   -- we entered from, but this will do for now
   modeS.shift_to = "nerf"
end

alias{_quit, NAV = {"ESC"}, ASCII = {"q"} }







function Page.scrollUp(maestro, event)
   maestro.zones.popup.contents:scrollUp(event.num_lines)
end
function Page.scrollDown(maestro, event)
   maestro.zones.popup.contents:scrollDown(event.num_lines)
end

local map = {
   SCROLL_UP = "scrollUp",
   SCROLL_DOWN = "scrollDown"
}
Page.default_keymaps = { map }








function Page.onShift(modeS)
   modeS.zones.popup:show()
end
function Page.onUnshift(modeS)
   modeS.zones.popup:hide()
end



return Page


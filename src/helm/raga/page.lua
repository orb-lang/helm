




local clone = import("core/table", "clone")
local RagaBase = require "helm:helm/raga/base"



local Page = clone(RagaBase, 2)

Page.name = "page"
Page.prompt_char = "❓"





local NAV = Page.NAV

local function _scrollDown(modeS)
   modeS.zones.popup:scrollDown()
end
for _, key in ipairs{"DOWN", "SHIFT_DOWN", "RETURN"} do
   NAV[key] = _scrollDown
end

local function _scrollUp(modeS)
   modeS.zones.popup:scrollUp()
end
for _, key in ipairs{"UP", "SHIFT_UP", "SHIFT_RETURN"} do
   NAV[key] = _scrollUp
end

local function _quit(modeS)
   -- #todo should have a stack of ragas and switch back to the one
   -- we entered from, but this will do for now
   modeS.shift_to = "nerf"
end

NAV.ESC = _quit








local ASCII = Page.ASCII

ASCII["q"] = _quit





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

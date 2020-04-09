

















assert(meta, "must have meta in _G")



local a         = require "anterm:anterm"
local Txtbuf    = require "helm/txtbuf"
local Rainbuf   = require "helm/rainbuf"
local Historian = require "helm/historian"
local Lex       = require "helm/lex"

local concat         = assert(table.concat)
local sub, gsub, rep = assert(string.sub),
                       assert(string.gsub),
                       assert(string.rep)






local clone    = import("core/table", "clone")
local EditBase = require "helm:helm/raga/edit"

local Nerf = clone(EditBase, 2)
Nerf.name = "nerf"
Nerf.prompt_char = "👉"






local function _insert(modeS, category, value)
   if tostring(modeS.txtbuf) == "" then
      modeS:setResults ""
      if value == "/" then
         modeS.shift_to = "search"
         return
      end
   end
   modeS.txtbuf:insert(value)
end

Nerf.ASCII = _insert
Nerf.UTF8 = _insert







local NAV = Nerf.NAV

local function _prev(modeS)
   local linestash
   if tostring(modeS.txtbuf) ~= ""
      and modeS.hist.cursor > modeS.hist.n then
      linestash = modeS.txtbuf
   end
   local prev_txtbuf, prev_result = modeS.hist:prev()
   if linestash then
      modeS.hist:append(linestash)
   end
   modeS:setTxtbuf(prev_txtbuf)
   modeS:setResults(prev_result)
   return modeS
end

function NAV.UP(modeS, category, value)
   local inline = modeS.txtbuf:up()
   if not inline then
      _prev(modeS)
   end
   return modeS
end

local function _advance(modeS)
   local new_txtbuf, next_result = modeS.hist:next()
   if not new_txtbuf then
      local added = modeS.hist:append(modeS.txtbuf)
      if added then
         modeS.hist.cursor = modeS.hist.n + 1
      end
      new_txtbuf = Txtbuf()
   end
   modeS:setTxtbuf(new_txtbuf)
   modeS:setResults(next_result)
   return modeS
end

function NAV.DOWN(modeS, category, value)
   local inline = modeS.txtbuf:down()
   if not inline then
      _advance(modeS)
   end

   return modeS
end



function NAV.RETURN(modeS, category, value)
   if modeS.txtbuf:shouldEvaluate() then
      modeS:eval()
   else
      modeS.txtbuf:nl()
   end
end

function NAV.CTRL_RETURN(modeS, category, value)
   modeS:eval()
end

function NAV.SHIFT_RETURN(modeS, category, value)
   modeS.txtbuf:nl()
end

-- Add aliases for terminals not in CSI u mode
Nerf.CTRL["^\\"] = NAV.CTRL_RETURN
NAV.ALT_RETURN = NAV.SHIFT_RETURN

local function _activateCompletion(modeS)
   if modeS.suggest.active_suggestions then
      modeS.shift_to = "complete"
      -- #todo seems like this should be able to be handled more centrally
      modeS.suggest.active_suggestions[1].selected_index = 1
      modeS.zones.suggest:beTouched()
      return true
   else
      return false
   end
end

function NAV.SHIFT_DOWN(modeS, category, value)
   if not _activateCompletion(modeS) then
      modeS.zones.results:scrollDown()
   end
end

function NAV.SHIFT_UP(modeS, category, value)
   if not _activateCompletion(modeS) then
      modeS.zones.results:scrollUp()
   end
end

function NAV.TAB(modeS, category, value)
   if not _activateCompletion(modeS) then
      modeS.txtbuf:paste("   ")
   end
end

function NAV.SHIFT_TAB(modeS, category, value)
   -- If we can't activate completion, nothing to do really
   _activateCompletion(modeS)
end





function Nerf.MOUSE(modeS, category, value)
   if value.scrolling then
      if value.button == "MB0" then
         modeS.zones.results:scrollUp()
      elseif value.button == "MB1" then
         modeS.zones.results:scrollDown()
      end
   end
end








function Nerf.onCursorChanged(modeS)
   modeS.suggest:update(modeS)
   EditBase.onCursorChanged(modeS)
end



return Nerf

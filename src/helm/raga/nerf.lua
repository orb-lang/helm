

















assert(meta, "must have meta in _G")
assert(write, "must have write in _G")



local a         = require "anterm:anterm"
local Txtbuf    = require "helm/txtbuf"
local Rainbuf   = require "helm/rainbuf"
local Historian = require "helm/historian"
local Lex       = require "helm/lex"


local concat         = assert(table.concat)
local sub, gsub, rep = assert(string.sub),
                       assert(string.gsub),
                       assert(string.rep)











local NAV    = {}
local CTRL   = {}
local ALT    = {}
-- ASCII, UTF8, PASTE and MOUSE are functions
local NYI    = {}





local Nerf = { NAV    = NAV,
               CTRL   = CTRL,
               ALT    = ALT,
               NYI    = NYI }

Nerf.name = "nerf"
Nerf.prompt_char = "👉"






local function _insert(modeS, category, value)
   if tostring(modeS.txtbuf) == "" then
      modeS:setResults ""
      if value == "/" then
         modeS:shiftMode("search")
         return
      end
   end
   modeS.txtbuf:insert(value)
end

Nerf.ASCII = _insert
Nerf.UTF8 = _insert

function Nerf.PASTE(modeS, category, value)
   if tostring(modeS.txtbuf) == "" then
      modeS:setResults ""
   end
   modeS.txtbuf:paste(value)
end







local function _prev(modeS)
   local prev_result, linestash
   if tostring(modeS.txtbuf) ~= ""
      and modeS.hist.cursor > modeS.hist.n then
      linestash = modeS.txtbuf
   end
   modeS.txtbuf, prev_result = modeS.hist:prev()
   if linestash then
      modeS.hist:append(linestash)
   end
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
      modeS.txtbuf = Txtbuf()
   else
      modeS.txtbuf = new_txtbuf
   end
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



function NAV.LEFT(modeS, category, value)
   return modeS.txtbuf:left()
end

function NAV.RIGHT(modeS, category, value)
   return modeS.txtbuf:right()
end

function NAV.ALT_LEFT(modeS,category,value)
  return modeS.txtbuf:leftWordAlpha()
end

function NAV.ALT_RIGHT(modeS,category,value)
  return modeS.txtbuf:rightWordAlpha()
end

function NAV.HYPER_LEFT(modeS,category,value)
  return modeS.txtbuf:startOfLine()
end

function NAV.HYPER_RIGHT(modeS,category,value)
  return modeS.txtbuf:endOfLine()
end

local function _eval(modeS)
   local more = modeS:eval()
   if not more then
      modeS.txtbuf = Txtbuf()
   end
   modeS.hist.cursor = modeS.hist.cursor + 1
end

function NAV.RETURN(modeS, category, value)
   if modeS.txtbuf:shouldEvaluate() then
      _eval(modeS)
   else
      modeS.txtbuf:nl()
   end
end

function NAV.CTRL_RETURN(modeS, category, value)
   _eval(modeS)
end

function NAV.SHIFT_RETURN(modeS, category, value)
   modeS.txtbuf:nl()
end

-- Add aliases for terminals not in CSI u mode
CTRL["^\\"] = NAV.CTRL_RETURN
NAV.ALT_RETURN = NAV.SHIFT_RETURN

local function _modeShiftOnEmpty(modeS)
   local buf = tostring(modeS.txtbuf)
   if buf == "" then
      modeS:shiftMode(modeS.raga_default)
      modeS:setResults("")
   end
end

function NAV.BACKSPACE(modeS, category, value)
   local shrunk =  modeS.txtbuf:deleteBackward()
   _modeShiftOnEmpty(modeS)
end

function NAV.DELETE(modeS, category, value)
   local shrunk = modeS.txtbuf:deleteForward()
   _modeShiftOnEmpty(modeS)
end

local function _activateCompletion(modeS)
   if modeS.suggest.active_suggestions then
      modeS:shiftMode("complete")
      -- #todo seems like this should be able to be handled more centrally
      modeS.suggest.active_suggestions[1].selected_index = 1
      modeS.zones.suggest.touched = true
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











CTRL["^A"] = NAV.HYPER_LEFT

CTRL["^E"] = NAV.HYPER_RIGHT

local function clear_txtbuf(modeS, category, value)
   modeS.txtbuf = Txtbuf()
   modeS.hist.cursor = modeS.hist.n + 1
   modeS:setResults("")
end

CTRL ["^L"] = clear_txtbuf

CTRL ["^R"] = function(modeS, category, value)
                 modeS:restart()
              end









ALT ["M-w"] = NAV.ALT_RIGHT

ALT ["M-b"] = NAV.ALT_LEFT






function Nerf.MOUSE(modeS, category, value)
   if value.scrolling then
      if value.button == "MB0" then
         modeS.zones.results:scrollUp()
      elseif value.button == "MB1" then
         modeS.zones.results:scrollDown()
      end
   end
end



return Nerf



















assert(meta, "must have meta in _G")
assert(write, "must have write in _G")



local a         = require "singletons/anterm"
local Txtbuf    = require "helm/txtbuf"
local Rainbuf   = require "helm/rainbuf"
local Historian = require "helm/historian"
local Lex       = require "helm/lex"


local concat         = assert(table.concat)
local sub, gsub, rep = assert(string.sub),
                       assert(string.gsub),
                       assert(string.rep)











local ASCII  = meta {}
local NAV    = {}
local CTRL   = {}
local ALT    = {}
local FN     = {}
local NYI    = {}





Nerf = { ASCII  = ASCII,
                NAV    = NAV,
                CTRL   = CTRL,
                ALT    = ALT,
                NYI    = NYI }






local up1, down1 = a.jump.up(), a.jump.down()

local function _prev(modeS)
   local prev_result, linestash
   if tostring(modeS.txtbuf) ~= ""
      and modeS.hist.cursor > #modeS.hist then
      linestash = modeS.txtbuf
   end
   modeS.txtbuf, prev_result = modeS.hist:prev()
   if linestash then
      modeS.hist:append(linestash)
   end
   if prev_result then
      modeS.zones.results:replace(Rainbuf(prev_result))
   else
      modeS.zones.results:replace ""
   end

   return modeS
end

function NAV.UP(modeS, category, value)
   modeS.firstChar = false
   local inline = modeS.txtbuf:up()
   if not inline then
      _prev(modeS)
   end

   return modeS
end

local function _advance(modeS)
   local next_p, next_result, new_txtbuf
   new_txtbuf, next_result, next_p = modeS.hist:next()
   if next_p then
      modeS.firstChar = true
      local added = modeS.hist:append(modeS.txtbuf)
      if added then
         modeS.hist.cursor = #modeS.hist + 1
      end
      modeS.txtbuf = Txtbuf()
   else
      modeS.txtbuf = new_txtbuf
   end
   modeS:clearResults()
   if next_result then
      modeS.zones.results:replace(Rainbuf(next_result))
   else
      modeS.zones.results:replace ""
   end
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
  return modeS.txtbuf:leftWord()
end

function NAV.ALT_RIGHT(modeS,category,value)
  return modeS.txtbuf:rightWord()

function NAV.HYPER_LEFT(modeS,category,value)
  return modeS.txtbuf:startOfLine()
end

function NAV.HYPER_RIGHT(modeS,category,value)
  return modeS.txtbuf:endOfLine()
end

function NAV.RETURN(modeS, category, value)
   -- eval or split line
   local eval = modeS.txtbuf:nl()
   if eval then
     local more = modeS:eval()
     if not more then
       modeS.txtbuf = Txtbuf()
       modeS.firstChar = true
     end
     modeS.hist.cursor = modeS.hist.cursor + 1
   end
end

local function _modeShiftOnEmpty(modeS)
   local buf = tostring(modeS.txtbuf)
   if buf == "" then
      modeS:shiftMode(modeS.raga_default)
      modeS.firstChar = true
      modeS:clearResults()
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

function NAV.SHIFT_DOWN(modeS, category, value)
   local results = modeS.zones.results.contents
   if results and results.more then
      results.offset = results.offset + 1
      modeS.zones.results.touched = true
   end
end

function NAV.SHIFT_UP(modeS, category, value)
   local results = modeS.zones.results.contents
   if results
    and results.offset
    and results.offset > 0 then
      results.offset = results.offset - 1
      modeS.zones.results.touched = true
   end
end













CTRL["^A"] = NAV.HYPER_LEFT

CTRL["^E"] = NAV.HYPER_RIGHT

local function clear_txtbuf(modeS, category, value)
   modeS.txtbuf = Txtbuf()
   modeS.hist.cursor = #modeS.hist + 1
   modeS.firstChar = true
   modeS.zones.results:replace ""
   modeS.zones:reflow(modeS)
end

CTRL ["^L"] = clear_txtbuf






ALT ["M-w"] = NAV.ALT_RIGHT

ALT ["M-b"] = NAV.ALT_LEFT






function Nerf.MOUSE(modeS, category, value)
   if value.scrolling then
      if value.button == "MB0" then
         modeS.modes.NAV.SHIFT_UP(modeS, category, value)
      elseif value.button == "MB1" then
         modeS.modes.NAV.SHIFT_DOWN(modeS, category, value)
      end
   end
end



return Nerf

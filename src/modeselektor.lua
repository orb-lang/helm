

























































































assert(meta, "must have meta in _G")
assert(write, "must have write in _G")
assert(ts, "must have ts in _G")











local Linebuf = require "linebuf"
local Historian = require "historian"



local ModeS = meta()








local ASCII = meta()
local NAV    = {}
local CTRL   = {}
local ALT    = {}
local FN     = {}
local MOUSE  = {}






















ModeS.modes = { ASCII  = ASCII,
                NAV    = NAV,
                CTRL   = CTRL,
                ALT    = ALT,
                MOUSE  = MOUSE,
                NYI    = true }






ModeS.special = {}





function ModeS.default(modeS, category, value)
    return write(ts(value))
end








function ModeS.insert(modeS, category, value)
    local success =  modeS.linebuf:insert(value)
    if not success then
      write("no insert: " .. value)
    else
      write(value)
    end
end








local STATCOL = 81
local STAT_TOP = 1
local STAT_RUN = 2

local function colwrite(str, col, row)
   col = col or STATCOL
   row = row or STAT_TOP
   local dash = a.stash()
             .. a.cursor.hide()
             .. a.jump(row, col)
             .. a.erase.right()
             .. str
             .. a.pop()
             .. a.cursor.show()
   write(dash)
end

local STAT_ICON = "◉ "

local function tf(bool)
   if bool then
      return ts("t", "true")
   else
      return ts("f", "false")
   end
end

function pr_mouse(m)
   local phrase = a.magenta(m.button) .. ": "
                     .. a.bright(m.kind) .. " " .. tf(m.shift)
                     .. " " .. tf(m.meta)
                     .. " " .. tf(m.ctrl) .. " " .. tf(m.moving) .. " "
                     .. tf(m.scrolling) .. " "
                     .. a.cyan(m.col) .. "," .. a.cyan(m.row)
   return phrase
end

local function mk_paint(fragment, shade)
   return function(category, action)
      return shade(category .. fragment .. action)
   end
end

local act_map = { MOUSE  = pr_mouse,
                  NAV    = mk_paint(": ", a.italic),
                  CTRL   = mk_paint(": ", c.field),
                  ALT    = mk_paint(": ", a.underscore),
                  ASCII  = mk_paint(": ", c.field),
                  NYI    = mk_paint(": ", a.red)}

local icon_map = { MOUSE = mk_paint(STAT_ICON, c.userdata),
                   NAV   = mk_paint(STAT_ICON, a.magenta),
                   CTRL  = mk_paint(STAT_ICON, a.blue),
                   ALT   = mk_paint(STAT_ICON, c["function"]),
                   ASCII = mk_paint(STAT_ICON, a.green),
                   NYI   = mk_paint(STAT_ICON .. "! ", a.red) }

local function icon_paint(category, value)
   assert(icon_map[category], "icon_paint NYI:" .. category)
   if category == "MOUSE" then
      return colwrite(icon_map[category]("", pr_mouse(value)))
    end
   return colwrite(icon_map[category]("", ts(value)))
end








function ModeS.paint(modeS)
  write(a.col(modeS.l_margin))
  write(a.erase.right())
  write(tostring(modeS.linebuf))
  write(a.col(modeS:cur_col()))
end

function ModeS.cur_col(modeS)
   return modeS.linebuf.cursor + modeS.l_margin - 1
end

function ModeS.nl(modeS)
   write(a.col(modeS.l_margin))
   if modeS.row + 1 <= modeS.max_row then
      write(a.jump.down())
      modeS.row  = modeS.row + 1
   else
      -- this gets complicated
   end
end

















function ModeS.act(modeS, category, value)
   assert(modeS.modes[category], "no category " .. category .. " in modeS")
   -- catch special handlers first
   if modeS.special[value] then
      return modeS.special[value](modeS, category, value)
   end
   icon_paint(category, value)

   -- Dispatch on value if possible
   if modeS.modes[category][value] then
      modeS.modes[category][value](modeS, category, value)

   -- otherwise fall back:
   elseif category == "ASCII" then
      -- hard coded for now
      modeS:insert(category, value)
   elseif category == "NAV" then
      if modeS.modes.NAV[value] then
         modeS.modes.NAV[value](modeS, category, value)
      else
         icon_paint("NYI", "NAV::" .. value)
      end
   elseif category == "MOUSE" then
      colwrite(pr_mouse(value), STATCOL, STAT_RUN)
   else
      icon_paint("NYI", category .. ":" .. value)
   end
   colwrite(modeS.hist.cursor, STATCOL, 3)
   return modeS:paint()
end






function ModeS.__call(modeS, category, value)
  return modeS:act(category, value)
end













function NAV.UP(modeS, category, value)
   modeS.linebuf = modeS.hist:prev()
   return modeS
end

function NAV.DOWN(modeS, category, value)
   local next_p
   modeS.linebuf, next_p = modeS.hist:next()
   if next_p then
      modeS.linebuf = Linebuf(1)
   end
   return modeS
end

function NAV.LEFT(modeS, category, value)
   return modeS.linebuf:left()
end

function NAV.RIGHT(modeS, category, value)
   return modeS.linebuf:right()
end

function NAV.RETURN(modeS, category, value)
   -- eval etc.
   modeS:nl()
   write(tostring(modeS.linebuf))
   modeS:nl()
   modeS.hist:append(modeS.linebuf)
   modeS.linebuf = Linebuf(1)
end

function NAV.BACKSPACE(modeS, category, value)
   return modeS.linebuf:d_back()
end

function NAV.DELETE(modeS, category, value)
   return modeS.linebuf:d_fwd()
end








function new(cfg)
  local modeS = meta(ModeS)
  modeS.linebuf = Linebuf(1)
  modeS.hist  = Historian()
  -- this will be more complex but
  modeS.l_margin = 4
  modeS.r_margin = 83
  modeS.row = 2
  modeS.history = {} -- make 3-d!
  modeS.hist_mark = 0
  return modeS
end

ModeS.idEst = new



return new



























































































assert(meta, "must have meta in _G")
assert(write, "must have write in _G")
assert(ts, "must have ts in _G")











local Linebuf = require "linebuf"



local ModeS = meta()








local INSERT = meta()
local NAV    = {}
local CTRL   = {}
local ALT    = {}
local FN     = {}
local MOUSE  = {}






















ModeS.modes = { INSERT = INSERT,
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
                  INSERT = mk_paint(": ", c.field),
                  NYI    = mk_paint(": ", a.red)}

local icon_map = { MOUSE = mk_paint(STAT_ICON, c.userdata),
                   NAV   = mk_paint(STAT_ICON, a.magenta),
                   CTRL  = mk_paint(STAT_ICON, a.blue),
                   ALT   = mk_paint(STAT_ICON, c["function"]),
                   INSERT = mk_paint(STAT_ICON, a.green),
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
   if modeS.special[value] then
      return modeS.special[value](modeS, category, value)
   elseif modeS.modes[category] then
      icon_paint(category, value)
      if category == "INSERT" then
         -- hard coded for now
         modeS:insert(category, value)
      elseif category == "NAV" then
         if modeS.modes.NAV[value] then
            modeS.modes.NAV[value](modeS, category, value)
         else
            icon_paint("NYI", "NAV:" .. value)
         end
      elseif category == "MOUSE" then
         colwrite(pr_mouse(value), STATCOL, STAT_RUN)
      else
         icon_paint("NYI", category .. ":" .. value)
      end
   else
      icon_paint(category, value)
      --colwrite("!! " .. category .. " " .. value, 1, 2)
      modeS:default(category, value)
   end

   return modeS:paint()
end






function ModeS.__call(modeS, category, value)
  return modeS:act(category, value)
end














function NAV.UP(modeS, category, value)
   if modeS.hist_mark > 1 then
      if modeS.hist_mark == #modeS.history then
         if tostring(modeS.linebuf) ~= "" then
            modeS.history[modeS.hist_mark + 1] = modeS.linebuf:suspend()
         end
         modeS.linebuf = modeS.history[modeS.hist_mark]:resume()
      else
         modeS.linebuf:suspend()
         modeS.hist_mark = modeS.hist_mark - 1
         modeS.linebuf = modeS.history[modeS.hist_mark]:resume()
      end
   end
end

function NAV.DOWN(modeS, category, value)
   if modeS.hist_mark < #modeS.history then
      -- not correct but no far (mutation should be handled)
      modeS.linebuf:suspend()
      modeS.hist_mark = modeS.hist_mark + 1
      modeS.linebuf = modeS.history[modeS.hist_mark]:resume()
   end
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
   modeS.history[#modeS.history + 1] = modeS.linebuf:suspend()
   modeS.hist_mark = #modeS.history
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

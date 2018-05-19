




























































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








local function self_insert(modeS, category, value)
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

function pr_mouse(m)
   local phrase = a.magenta(m.button) .. ": "
                     .. a.bright(kind) .. " " .. ts(m.shift)
                     .. " " .. ts(m.meta)
                     .. " " .. ts(m.ctrl) .. " " .. ts(m.moving) .. " "
                     .. ts(m.scrolling) .. " "
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














function repaint(modeS)
  write(a.col(modeS.l_margin))
  write(a.erase.right())
  write(tostring(modeS.linebuf))
  write(a.col(modeS:cur_col()))
end

function ModeS.cur_col(modeS)
   return modeS.linebuf.cursor + modeS.l_margin - 1
end

function ModeS.act(modeS, category, value)
  assert(modeS.modes[category], "no category " .. category .. " in modeS")
   if modeS.special[value] then
      return modeS.special[value](modeS, category, value)
   elseif modeS.modes[category] then
      icon_paint(category, value)
      if category == "INSERT" then
         -- hard coded for now
         self_insert(modeS, category, value)
         repaint(modeS)
      elseif category == "NAV" then
        if value == "RETURN" then
          write(a.col() .. a.jump.down(1)
                .. tostring(modeS.linebuf) .. a.col() .. a.jump.down(1))
        elseif value == "LEFT" then
          modeS.linebuf:left()
          write(a.col(modeS:cur_col()))
          colwrite(ts(move),nil,3)
        elseif value == "RIGHT" then
          modeS.linebuf:right()
          write(a.col(modeS:cur_col()))
          colwrite(ts(move),nil,3)
        end -- etc, jump table
      end
   else
      icon_paint(category, value)
      --colwrite("!! " .. category .. " " .. value, 1, 2)
      return modeS:default(category, value)
   end
end





function ModeS.__call(modeS, category, value)
  return modeS:act(category, value)
end





function new()
  local modeS = meta(ModeS)
  modeS.linebuf = Linebuf(1)
  -- this will be more complex but
  modeS.l_margin = 4
  modeS.r_margin = 83
  return modeS
end

ModeS.idEst = new



return new



























































































assert(meta, "must have meta in _G")
assert(write, "must have write in _G")
assert(ts, "must have ts in _G")











local Linebuf = require "linebuf"
local Historian = require "historian"

local concat = assert(table.concat)
local sub, gsub = assert(string.sub), assert(string.gsub)



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
                NYI    = {} }






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








function ModeS.paint_row(modeS)
  write(a.col(modeS.l_margin))
  write(a.erase.right())
  write(tostring(modeS.linebuf))
  write(a.col(modeS:cur_col()))
end

function ModeS.cur_col(modeS)
   return modeS.linebuf.cursor + modeS.l_margin - 1
end

function ModeS.nl(modeS)
   write(a.col(modeS.l_margin).. a.jump.down(1))
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
   colwrite(a.bold(modeS.hist.cursor), STATCOL + 6, 3)
   for i,v in ipairs(modeS.hist) do
      colwrite(tostring(v.line), STATCOL, i + 4)
   end
   return modeS:paint_row()
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
      modeS.linebuf = Linebuf()
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
   modeS:eval()
   modeS.hist:append(modeS.linebuf)
   modeS.linebuf = Linebuf()
end

function NAV.BACKSPACE(modeS, category, value)
   return modeS.linebuf:d_back()
end

function NAV.DELETE(modeS, category, value)
   return modeS.linebuf:d_fwd()
end








local function cursor_begin(modeS, category, value)
   modeS.linebuf.cursor = 1
end

CTRL["^A"] = cursor_begin

local function cursor_end(modeS, category, value)
   modeS.linebuf.cursor = #modeS.linebuf.line + 1
end

CTRL["^E"] = cursor_end












function ModeS.write(modeS, str)
   local nl = a.col(modeS.l_margin) .. a.jump.down()
   local phrase, num_subs = gsub(str, "\n", nl)
   write(phrase)
   -- modeS.row = modeS.row + num_subs
end



local function gatherResults(success, ...)
  local n = select('#', ...)
  return success, { n = n, ... }
end



function ModeS.printResults(modeS, results)
  for i = 1, results.n do
    results[i] = ts(results[i])
  end
  modeS:write(concat(results, '   '))
end



function ModeS.prompt(modeS)
   write(a.jump(modeS.replLine, 1) .. "👉 ")
end



function ModeS.clearResult(modeS)
   write(a.erase.box(3, 1, modeS.max_row, modeS.r_margin))
end



function ModeS.eval(modeS)
   local line = tostring(modeS.linebuf)
   local chunk  = modeS.buffer .. line
   -- first we prefix return
   local f, err = loadstring('return ' .. chunk, 'REPL')

   if not f then
      f, err = loadstring(chunk, 'REPL') -- try again without return
   end
   if not f then
      local head = sub(chunk, 1, 1)
      if head == "=" then -- take pity on old-school Lua hackers
         f, err = loadstring('return ' .. sub(chunk,2), 'REPL')
      end -- more special REPL prefix soon
   end
   if f then
      modeS.buffer = ""
      local success, results = gatherResults(xpcall(f, debug.traceback))

      if success then
      -- successful call
         modeS:clearResult()
         if results.n > 0 then
            modeS:printResults(results)
         end
      else
      -- error
         modeS:clearResult()
         modeS:write(results[1])
      end
   else
      if err:match "'<eof>'$" then
         -- Lua expects some more input; stow it away for next time
         modeS.buffer = chunk .. '\n'
         return '...'
      else
         modeS:write(err)
         modeS.buffer = ''
      end
   end
   modeS:prompt()
end








function new(cfg)
  local modeS = meta(ModeS)
  modeS.linebuf = Linebuf()
  modeS.buffer = ""
  modeS.hist  = Historian()
  modeS.hist:append(modeS.linebuf)
  -- this will be more complex but
  modeS.l_margin = 4
  modeS.r_margin = 80
  modeS.row = 2
  modeS.replLine = 2
  return modeS
end

ModeS.idEst = new



return new

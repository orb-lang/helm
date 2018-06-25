
























































































assert(meta, "must have meta in _G")
assert(write, "must have write in _G")
assert(ts, "must have ts in _G")











local Linebuf   = require "txtbuf"
local Resbuf    = require "resbuf"
local Historian = require "historian"
local Lex       = require "lex"

local concat         = assert(table.concat)
local sub, gsub, rep = assert(string.sub),
                       assert(string.gsub),
                       assert(string.rep)



local ModeS = meta()








local ASCII  = meta {}
local NAV    = {}
local CTRL   = {}
local ALT    = {}
local FN     = {}
local MOUSE  = {}
local NYI    = {}






















ModeS.modes = { ASCII  = ASCII,
                NAV    = NAV,
                CTRL   = CTRL,
                ALT    = ALT,
                MOUSE  = MOUSE,
                NYI    = NYI }





ModeS.REPL_LINE = 2






ModeS.special = {}





function ModeS.default(modeS, category, value)
    return write(ts(value))
end








function ModeS.insert(modeS, category, value)
    local success =  modeS.linebuf:insert(value)
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

local function pr_mouse(m)
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
                  ASCII  = mk_paint(": ", c.table),
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









function ModeS.cur_col(modeS)
   return modeS.linebuf.cursor + modeS.l_margin - 1
end

function ModeS.nl(modeS)
   write(a.col(modeS.l_margin).. a.jump.down(1))
end









function ModeS.write(modeS, str)
   local nl = a.col(modeS.l_margin) .. a.jump.down(1)
   local phrase, num_subs
   phrase, num_subs = gsub(str, "\n", nl)
   write(a.cursor.hide())
   write(phrase)
   write(a.cursor.show())
end




function ModeS.paint_row(modeS)
   local lb = Lex.lua_thor(modeS.buffer .. tostring(modeS.linebuf))
   write(a.cursor.hide())
   write(a.jump(modeS.repl_line, modeS.l_margin))
   write(a.erase.right())
   modeS:write(concat(lb))
   write(a.col(modeS:cur_col()))
   write(a.cursor.show())
end



function ModeS.printResults(modeS, results)
   local rainbuf = {}
   modeS:write(a.rc(modeS.repl_line + 1, modeS.l_margin))
   for i = 1, results.n do
      if results.frozen then
         rainbuf[i] = results[i]
      else
         rainbuf[i] = ts(results[i])
      end
   end
   modeS:write(concat(rainbuf, '   '))
end



function ModeS.prompt(modeS)
   write(a.jump(modeS.repl_line, 1) .. "👉 ")
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
   return modeS:paint_row()
end





function ModeS.__call(modeS, category, value)
  return modeS:act(category, value)
end













function NAV.UP(modeS, category, value)
   modeS:clearResult()
   local prev_result, linestash
   if tostring(modeS.linebuf) ~= ""
      and modeS.hist.cursor > #modeS.hist then
      linestash = modeS.linebuf
   end
   modeS.linebuf, prev_result = modeS.hist:prev()
   if linestash then
      modeS.hist:append(linestash)
   end
   if prev_result then
      modeS:printResults(prev_result)
   else
      modeS:clearResult()
   end
   return modeS
end

function NAV.DOWN(modeS, category, value)
   modeS:clearResult()
   local next_p, next_result
   modeS.linebuf, next_result, next_p = modeS.hist:next()
   if next_p then
      modeS.linebuf = Linebuf()
   end
   if next_result then
      modeS:printResults(next_result)
   else
      modeS:clearResult()
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
   modeS.linebuf = Linebuf()
   modeS.hist.cursor = modeS.hist.cursor + 1
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
   modeS.linebuf.cursor = #modeS.linebuf.lines + 1
end

CTRL["^E"] = cursor_end







local function gatherResults(success, ...)
  local n = select('#', ...)
  return success, { n = n, ... }
end



function ModeS.clearResult(modeS)
   write(a.erase.box(3, 1, modeS.max_row, modeS.r_margin))
end



function ModeS.eval(modeS)
   local line = tostring(modeS.linebuf)
   local chunk  = modeS.buffer .. line
   local success, results
   -- first we prefix return
   local f, err = loadstring('return ' .. chunk, 'REPL')

   if not f then
      -- try again without return
      f, err = loadstring(chunk, 'REPL')
   end
   if not f then
      local head = sub(chunk, 1, 1)
      if head == "=" then -- take pity on old-school Lua hackers
         f, err = loadstring('return ' .. sub(chunk,2), 'REPL')
      end -- more special REPL prefix soon
   end
   if f then
      modeS.linebuf = Linebuf(modeS.buffer .. tostring(modeS.linebuf))
      modeS.buffer = ""
      modeS.repl_line = modeS.REPL_LINE
      success, results = gatherResults(xpcall(f, debug.traceback))
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
         modeS.repl_line = modeS.repl_line + 1
         write '...'
         return true
      else
         modeS.repl_line = modeS.REPL_LINE
         modeS:clearResult()
         modeS:write(err)
         modeS.buffer = ""
         -- pass through to default.
      end
   end

   modeS.hist:append(modeS.linebuf, results, success)
   modeS.hist.cursor = #modeS.hist
   if success then modeS.hist.results[modeS.linebuf] = results end
   modeS:prompt()
end








function new(cfg)
  local modeS = meta(ModeS)
  modeS.linebuf = Linebuf()
  modeS.buffer = ""
  modeS.hist  = Historian()
  modeS.hist.cursor = #modeS.hist + 1
  -- this will be more complex but
  modeS.l_margin = 4
  modeS.r_margin = 80
  modeS.row = 2
  modeS.repl_line = 2
  return modeS
end

ModeS.idEst = new



return new

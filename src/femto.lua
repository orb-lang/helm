

















sql = require "sqlite"
L = require "lpeg"
lfs = require "lfs"
ffi = require "ffi"
bit = require "bit"
ffi.reflect = require "reflect"
uv = require "luv"

















local core = require "core"
string.cleave, string.litpat = core.cleave, core.litpat
meta = core.meta
getmeta, setmeta = getmetatable, setmetatable
coro = coroutine








a = require "anterm"
color = require "color"
ts = color.ts
c = color.color
watch = require "watcher"









local usecolors
stdout = ""

if uv.guess_handle(1) == "tty" then
  stdout = uv.new_tty(1, false)
  usecolors = true
else
  stdout = uv.new_pipe(false)
  uv.pipe_open(utils.stdout, 1)
  usecolors = false
end

if not usecolors then
   ts = tostring
   -- #todo make this properly black and white ts
end

function write(str)
   uv.write(stdout, str)
end





local modeS = require "modeselektor" ()



function print(...)
  local n = select('#', ...)
  local arguments = {...}
  for i = 1, n do
    arguments[i] = tostring(arguments[i])
  end
  uv.write(stdout, table.concat(arguments, "\t") .. "\n")
end


--  *** tty setup

if uv.guess_handle(0) ~= "tty" or
   uv.guess_handle(1) ~= "tty" then
  -- Entry point for other consumers!
  error "stdio must be a tty"
end

local stdin = uv.new_tty(0, true)


--  *** utilities

local function gatherResults(success, ...)
  local n = select('#', ...)
  return success, { n = n, ... }
end

local function printResults(results)
  for i = 1, results.n do
    results[i] = ts(results[i])
  end
  print(table.concat(results, '\t'))
end

local buffer = ''

local function evaluateLine(line)
   if string.byte(line) == 17 then -- ^Q
      uv.stop()
      return 0
   end
   local chunk  = buffer .. line
   local f, err = loadstring('return ' .. chunk, 'REPL') -- first we prefix return

   if not f then
      f, err = loadstring(chunk, 'REPL') -- try again without return
   end

   if f then
      buffer = ''
      local success, results = gatherResults(xpcall(f, debug.traceback))

      if success then
      -- successful call
         if results.n > 0 then
            printResults(results)
         end
      else
      -- error
         print(results[1])
      end
   else
      if err:match "'<eof>'$" then
         -- Lua expects some more input; stow it away for next time
         buffer = chunk .. '\n'
         return '...'
      else
         print(err)
         buffer = ''
      end
   end

   return '👉  '
end

local function displayPrompt(prompt)
  uv.write(stdout, prompt)
end



-- Deprecated, but useful if I want, y'know, a REPL
local function onread(err, line)
  if err then error(err) end
  if line then
    local prompt = evaluateLine(line)
    displayPrompt(prompt)
  else
    uv.close(stdin)
  end
end





















local keybuf = {}
local sub, byte = string.sub, string.byte
local concat = table.concat

local linebuf = { line = "",
                  ndx  = 0 }

local max_row, mac_col = uv.tty_get_winsize(stdin)










-- device report parsing goes in anterm
--
local function cursor_pos(str)
   local row, col = core.cleave(str, ";")
   return tonumber(row), tonumber(col)
end

local STATCOL = 81
local STAT_TOP = 1
local STAT_RUN = 2

-- more like jumpwrite at this point but w/e
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

local STAT_ICON = "◉"

local function isnum(char)
   return char >= "0" and char <= "9"
end

local function isalpha(char)
   return (char >= "A" and char <= "z")
      or  (char >= "a" and char <= "z")
end





function pr_mouse(m)
   local phrase = a.magenta(m.button) .. ": "
                     .. a.bright(kind) .. " " .. ts(m.shift)
                     .. " " .. ts(m.meta)
                     .. " " .. ts(m.ctrl) .. " " .. ts(m.moving) .. " "
                     .. ts(m.scrolling) .. " "
                     .. a.cyan(m.col) .. "," .. a.cyan(m.row)
   return phrase
end











local function mk_paint(label, shade)
   return function(action)
      return shade(label .. " " .. action)
   end
end

local act_map = { MOUSE  = pr_mouse,
                  NAV    = mk_paint("NAV:", a.italic),
                  CTRL   = mk_paint("CTRL:", c.field),
                  ALT    = mk_paint("ALT:", a.underscore),
                  INSERT = mk_paint("INS:", c.field)}
                  -- Device reports, function keys...

-- I believe the kids call that 'currying'

local function act(category, action)
   if act_map[category] then
      colwrite(act_map[category](action), STATCOL, STAT_RUN)
   else
      colwrite(category .. ":" ..action, STATCOL, STAT_RUN)
   end
end

local m_parse, is_mouse = a.mouse.parse_fast, a.mouse.ismousemove
local navigation, is_nav = a.navigation, a.is_nav

local function process_escapes(seq)
   if is_nav(seq) then
      act("NAV", navigation[seq] )
   elseif #seq == 1 then
      act("NAV", "ESC") -- I think of escape as navigation in modal systems
   end
   if is_mouse(seq) then
      local m = m_parse(seq)
      act("MOUSE", m)
   elseif #seq == 2 and byte(sub(seq,2,2)) < 128 then
      -- Meta
      local key = "M-" .. sub(seq,2,2)
      colwrite(a.bold(STAT_ICON) .. " : " .. key)
      act("ALT", key)
   end
end

local navigation = a.navigation

local function onseq(err,seq)
   if err then error(err) end
   local head = byte(seq)
   -- ^Q hard coded as quit, for now
   if head == 17 then
      femto.cooked()
      write(a.mouse.track(false))
      uv.stop()
      return 0
   end
   -- Escape sequences
   if head == 27 then
      local color
      if navigation[seq] or #seq == 1 then
         color = c.userdata
      else
         color = a.red
      end
      colwrite(color(STAT_ICON) .. " : " .. ts(seq))
      return process_escapes(seq)
   end
   -- Control sequences
   if head <= 31 and not navigation[seq] then
      local ctrl = "^" .. string.char(head + 64)
      colwrite(c.field(STAT_ICON) .. " : " .. ctrl)
      return act("CTRL", ctrl)
   elseif navigation[seq] then
      colwrite(a.green(STAT_ICON))
      return act("NAV", navigation[seq])
   end

   colwrite(a.green(STAT_ICON) .. " : " .. seq)
   return act("INSERT", byte(seq))
end



-- Get names for as many values as possible
-- into the colorizer
color.allNames()
-- This switches screens and does a wipe,
-- then puts the cursor at 1,1.
write "\x1b[?47h\x1b[2J\x1b[H"
print "an repl, plz reply uwu 👀"
displayPrompt '👉  '
-- Crude hack to choose raw mode at runtime
if arg[1] == "-r" then
   femto.raw()
   --uv.tty_set_mode(stdin, 2)
   -- mouse mode
   write(a.mouse.track(true))
   uv.read_start(stdin, onseq)
else
   uv.read_start(stdin, onread)
end



-- main loop
local retcode =  uv.run('default')
-- Restore main screen
print '\x1b[?47l'

if retcode ~= true then
   error(retcode)
end

print("kthxbye")
return retcode

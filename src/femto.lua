














sql = require "sqlite"
L = require "lpeg"
lfs = require "lfs"
ffi = require "ffi"
bit = require "bit"
ffi.reflect = require "reflect"
uv = require "luv"

















local core = require "core"
string.cleave, string.litpat = core.cleave, core.litpat
string.utf8 = core.utf8
string.codepoints = core.codepoints
table.splice = core.splice
table.clone = core.clone
utf8 = core.utf8
codepoints = core.codepoints
meta = core.meta
getmeta, setmeta = getmetatable, setmetatable
coro = coroutine

local concat = table.concat








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



function print(...)
  local n = select('#', ...)
  local arguments = {...}
  for i = 1, n do
    arguments[i] = tostring(arguments[i])
  end
  uv.write(stdout, concat(arguments, "\t") .. "\n")
end






if uv.guess_handle(0) ~= "tty" or
   uv.guess_handle(1) ~= "tty" then
  -- Entry point for other consumers!
  error "stdio must be a tty"
end

local stdin = uv.new_tty(0, true)






local modeS = require "modeselektor" ()
modeS.max_row, modeS.max_col = uv.tty_get_winsize(stdin)




--  *** utilities

local function gatherResults(success, ...)
  local n = select('#', ...)
  return success, { n = n, ... }
end

local function printResults(results)
  for i = 1, results.n do
    results[i] = ts(results[i])
  end
  print(concat(results, '\t'))
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












local byte, sub = string.byte, string.sub
local m_parse, is_mouse = a.mouse.parse_fast, a.mouse.ismousemove
local navigation, is_nav = a.navigation, a.is_nav

local function process_escapes(seq)
   if is_nav(seq) then
      return modeS("NAV", navigation[seq] )
   elseif #seq == 1 then
      modeS("NAV", "ESC") -- I think of escape as navigation in modal systems
   end
   if is_mouse(seq) then
      local m = m_parse(seq)
      return modeS("MOUSE", m)
   elseif #seq == 2 and byte(sub(seq,2,2)) < 128 then
      -- Meta
      local key = "M-" .. sub(seq,2,2)
      return modeS("ALT", key)
   else
      return modeS("NYI", seq)
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
      return process_escapes(seq)
   end
   -- Control sequences
   if head <= 31 and not navigation[seq] then
      local ctrl = "^" .. string.char(head + 64)
      return modeS("CTRL", ctrl)
   elseif navigation[seq] then
      return modeS("NAV", navigation[seq])
   end
   -- Printables
   if head > 31 and head < 127 then
      return modeS("ASCII", seq)
   else
      -- wchars go here
      return modeS("NYI", seq)
   end
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

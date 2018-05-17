













sql = require "sqlite"

lfs = require "lfs"
ffi = require "ffi"
bit = require "bit"

ffi.reflect = require "reflect"

uv = require "luv"

L = require "lpeg"

a = require "anterm"

c = require "color"
ts = c.ts

core = require "core"

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
   c.ts = tostring
   -- #todo make this properly black and white ts
end

function print(...)
  local n = select('#', ...)
  local arguments = {...}
  for i = 1, n do
    arguments[i] = tostring(arguments[i])
  end
  uv.write(stdout, table.concat(arguments, "\t") .. "\n")
end

function write(str)
   uv.write(stdout, str)
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
    results[i] = c.ts(results[i])
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










-- This will be called parse_digits and be substantially more complex.
--
local function cursor_pos(str)
   local row, col = core.cleave(str, ";")
   return tonumber(row), tonumber(col)
end

-- more like jumpwrite at this point but w/e
local function colwrite(str, col, row)
   col = col or 81
   row = row or 1
   local dash = a.stash()
             .. a.jump(row, col)
             .. a.erase.right()
             .. str
             .. a.pop()

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




















--

local __navigation = {  UP       = "\x1b[A",
                        DOWN     = "\x1b[B",
                        RIGHT    = "\x1b[C",
                        LEFT     = "\x1b[D",
                        SHIFT_UP = "\x1b[1;2A",
                        SHIFT_DOWN = "\x1b[1;2B",
                        SHIFT_RIGHT = "\x1b[1;2C",
                        SHIFT_LEFT  = "\x1b[1;2D",
                        HYPER_UP    = "\x1b[5~",
                        HYPER_DOWN  = "\x1b[6~",
                        HYPER_RIGHT = "\x1b[F",
                        HYPER_LEFT  = "\x1b[H",
                        ALT_UP    = "\x1b\x1b[A",
                        ALT_DOWN  = "\x1b\x1b[B",
                        ALT_RIGHT = "\x1bf", -- heh
                        ALT_LEFT  = "\x1bb",
                        SHIFT_ALT_UP = "\x1b[1;10A",
                        SHIFT_ALT_DOWN = "\x1b[1;10B",
                        SHIFT_ALT_RIGHT = "\x1b[1;10C",
                        SHIFT_ALT_LEFT  = "\x1b[1;10D",
                        SHIFT_TAB  = "\x1b[Z",
                        ALT_TAB    = "\x1b\t",
                        NEWLINE    = "\n",
                        RETURN     = "\r",
                        TAB        = "\t"
                     }

-- it is possible to coerce a terminal into sending these, apparently:

local __alt_nav = {  UP       = "\x1bOA",
                     DOWN     = "\x1bOB",
                     RIGHT    = "\x1bOC",
                     LEFT     = "\x1bOD",
                  }

local __control = {  ZERO = "\0",
                   }

local navigation = {}
local control = {}

--  Then invert

for k,v in pairs(__navigation) do
   navigation[v] = k
end
for k,v in pairs(__alt_nav) do
   navigation[v] = k
end
for k,v in pairs(__control) do
   control[v] = k
end

__navigation, __control, __alt_nav = nil, nil, nil

local function act(action, category)
   colwrite(a.yellow(action), 81, 2)
end

local function litprint(seq)
   local phrase = ""
   for i = 1, #seq do
      phrase = phrase .. ":" .. byte(seq, i)
   end
   return phrase
end

local function ismousemove(seq)
   if sub(seq, 1, 3) == "\x1b[M" then
      return true
   end
end

local buttons = {[0] ="MB0", "MB1", "MB2", "MBRELEASE"}

local function process_escapes(seq)
   if navigation[seq] then
      act(navigation[seq], "navigation")
   elseif #seq == 1 then
      act("ESC", "control")
   end
   if ismousemove(seq) then
      local kind, col, row = byte(seq,4), byte(seq, 5), byte(seq, 6)
      col = col - 32
      row = row - 32
      kind = kind - 32
      -- Get button
      local button = buttons[kind % 4]
      -- Get modifiers
      kind = bit.rshift(kind, 2)
      local shift = kind % 2 == 1 and true or false
      kind = bit.rshift(kind, 1)
      local meta = kind % 2 == 1 and true or false
      kind = bit.rshift(kind, 1)
      local ctrl = kind % 2 == 1 and true or false
      kind = bit.rshift(kind, 1)
      local moving = kind % 2 == 1 and true or false
      -- we skip a bit that seems to just mirror the motion
      -- it may be pixel level, I can't tell and idk
      local scrolling = kind == 2 and true or false
      local phrase = a.magenta(button) .. ": "
                     .. a.bright(kind) .. " " .. ts(shift) .. " " .. ts(meta)
                     .. " " .. ts(ctrl) .. " " .. ts(moving) .. " "
                     .. ts(scrolling) .. " "
                     .. a.cyan(col) .. "," .. a.cyan(row)

      act(phrase)
   end
end

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
         color = a.magenta
      else
         color = a.red
      end
      colwrite(color(STAT_ICON) .. " : " .. c.ts(seq))
      return process_escapes(seq)
   end
   -- Control sequences
   if head <= 31 and not navigation[seq] then
      local ctrl = "^" .. string.char(head + 64)
      colwrite(a.blue(STAT_ICON) .. " : " .. ctrl)
      return act(ts(seq), "control")
   elseif navigation[seq] then
      colwrite(a.green(STAT_ICON))
      return act(seq, "navigation")
   end

   colwrite(a.green(STAT_ICON) .. " : " .. seq)
   return act(seq, "entry")

end



-- Get names for as many values as possible
-- into the colorizer
c.allNames()
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

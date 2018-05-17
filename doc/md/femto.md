# Femto


I just got orb stood up in the pylon bootloader distribution.


I am excited about this.


## includes

This all goes into global space for now.  Our more sophisticated loader will
handle namespace isolation. Meanwhile we're building a repl, so.


First we load everything that might reasonable expect a stock namespace.


All of these are exceedingly well-behaved.

```lua
sql = require "sqlite"
L = require "lpeg"
lfs = require "lfs"
ffi = require "ffi"
bit = require "bit"
ffi.reflect = require "reflect"
uv = require "luv"
```
### Djikstra Insertion Point

Although we're not doing so yet, this is where we will set up Djikstra mode
for participating code.  We then push that up through the layers, and it lands
as close to C level as practical.

## core

The ``core`` library is shaping up as a place to keep alterations to the global
namespace and standard library.


This prelude belongs in ``pylon``; it, and ``core``, will eventually end up there.

```lua
local core = require "core"
string.cleave, string.litpat = core.cleave, core.litpat
meta = core.meta
getmeta, setmeta = getmetatable, setmetatable
coro = coroutine
```

Primitives for terminal manipulation.


Arguably don't belong here. ``watch`` is unused at present, it will be useful
in Orb relatively soon.

```lua
a = require "anterm"
c = require "color"
ts = c.ts
watch = require "watcher"
```

This is all from the ``luv`` repl example, which has been an excellent launching
off point.  Thanks Tim Caswell!


It's getting phased out bit by bit.

```lua
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
```
```lua
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
```
## Reader

The reader takes a stream of data from ``stdin``, asynchronously, and
processes it into tokens, which stream to the recognizer.


#### keybuf

 Currently the keybuf is a simple array that holds bytes until we have
enough for the lexer.


It is cleared and reused, to avoid a glut of allocations and allow the tracer
to follow it.


Soon I'll move the remaining local state into an instance table, to make
``femto`` re-entrant.

```lua
local keybuf = {}
local sub, byte = string.sub, string.byte
local concat = table.concat

local linebuf = { line = "",
                  ndx  = 0 }

local max_row, mac_col = uv.tty_get_winsize(stdin)

```
### helper functions

Writes will eventually happen in their own library.  Right now we're building
the minimum viable loop.

```lua
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
```
### process_escapes(seq)

After flailing about and writing what was no doubt a good parser for
individual byte sequences, I discovered that ``uv`` gives them to me a seq at a
time.


Because of course it does.


So we're just going to make this a jump table that translates ``xterm`` directly
to english.


I'm also going to switch to ``x1b``, which is more visually distinguished.


To avoid extraneous quoting, we define the tokens as keys, and their escape
strings as values.
```lua

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
                        TAB        = "\t",
                        BACKSPACE  = "\127",
                        DELETE     = "\x1b[3~",
                     }
```

It's possible to coerce a terminal into sending these, apparently:

```lua
local __alt_nav = {  UP       = "\x1bOA",
                     DOWN     = "\x1bOB",
                     RIGHT    = "\x1bOC",
                     LEFT     = "\x1bOD",
                  }
```

I don't know why, and if anyone does, please let me know.


I'm fairly sure those are the only valid meanings for the above escape
strings.


Annnnyway, printable control characters:

```lua
local __control = { HT = "\t",
                    LF = "\n",
                    CR = "\r" }

local navigation = {}
local control = {}

--  Then invert

for k,v in pairs(__navigation) do
   navigation[v] = k
end
for k,v in pairs(__alt_nav) do
   navigation[v] = k
end

__navigation, __alt_nav = nil, nil, nil

function pr_mouse(m)
   local phrase = a.magenta(m.button) .. ": "
                     .. a.bright(kind) .. " " .. ts(m.shift)
                     .. " " .. ts(m.meta)
                     .. " " .. ts(m.ctrl) .. " " .. ts(m.moving) .. " "
                     .. ts(m.scrolling) .. " "
                     .. a.cyan(m.col) .. "," .. a.cyan(m.row)
   return phrase
end

local act_map = { MOUSE = pr_mouse}

local function act(category, action)
   if act_map[category] then
      colwrite(act_map[category](action), 81, 2)
   else
      colwrite(action, 81, 2)
   end
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

local buttons = {[0] ="MB0", "MB1", "MB2", "MBNONE"}

local rshift = bit.rshift
local function process_escapes(seq)
   if navigation[seq] then
      act("NAV", navigation[seq] )
   elseif #seq == 1 then
      act("CTRL", "ESC")
   end
   if ismousemove(seq) then
      local kind, col, row = byte(seq,4), byte(seq, 5), byte(seq, 6)
      kind = rshift(kind, 32)
      local m = {row = rshift(row, 5), col = rshift(col, 5)}
      -- Get button
      m.button = buttons[kind % 4]
      -- Get modifiers
      kind = rshift(kind, 2)
      m.shift = kind % 2 == 1
      kind = rshift(kind, 1)
      m.meta = kind % 2 == 1
      kind = rshift(kind, 1)
      m.ctrl = kind % 2 == 1
      kind = rshift(kind, 1)
      m.moving = kind % 2 == 1
      -- we skip a bit that seems to just mirror the motion
      -- it may be pixel level, I can't tell and idk
      m.scrolling = kind == 2


      act("MOUSE", m)
   elseif #seq == 2 and byte(seq[2]) < 128 then

      -- Meta
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
      return act("CTRL", ctrl)
   elseif navigation[seq] then
      colwrite(a.green(STAT_ICON))
      return act("NAV", navigation[seq])
   end

   colwrite(a.green(STAT_ICON) .. " : " .. seq)
   return act("INSERT", byte(seq))

end
```
```lua
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
```

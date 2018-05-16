# Femto


I just got orb stood up in the pylon bootloader distribution.


I am excited about this.


## includes

This all goes into global space for now.  Our more sophisticated loader will
handle namespace isolation. Meanwhile we're building a repl, so.

```lua
sql = require "sqlite"

lfs = require "lfs"
ffi = require "ffi"

ffi.reflect = require "reflect"

uv = require "luv"

L = require "lpeg"

a = require "anterm"

c = require "color"

core = require "core"

watch = require "watcher"
```
#### utils

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

-- more like jumpwrite at this point but w/
local function colwrite(str, col, row)
   col = col or 81
   row = row or 1
   local dash = a.stash()
             .. a.jump(1, col)
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

local function process_escapes(seq)
   local term = sub(seq, -1)
   local csi  = sub(seq, 2, 2) == "[" and true or false
   local payload
   local ltrim = csi and 3 or 2
   if #seq > ltrim then
      payload = sub(seq, ltrim, -1)
   end
   if term == "R" then
      local row, col = cursor_pos(payload)
      -- send them along
   elseif term == "A" then
      -- up
   elseif term == "B" then
      -- down
   elseif term == "C" then
      -- left
   elseif term == "D" then
      -- right
   else
      return write(seq)
   end
end

local function onseq(err,seq)
   if err then error(err) end

   if byte(seq) == 27 then
      colwrite(a.magenta(STAT_ICON) .. " : " .. c.ts(seq))
      process_escapes(seq)
      return
   end
   colwrite(a.green(STAT_ICON) .. " : " .. seq)
   write(seq)
end
```
```lua
-- Get names for as many values as possible
-- into the colorizer
c.allNames()
-- This switches screens and does a wipe,
-- then puts the cursor at 1,1.
write '\27[?47h\27[2J\27[H'
print "an repl, plz reply uwu 👀"
displayPrompt '👉  '
-- Crude hack to choose raw mode at runtime
if arg[1] == "-r" then
   femto.raw()
   uv.read_start(stdin, onseq)
else
   uv.read_start(stdin, onread)
end



-- main loop
local retcode = uv.run('default')
-- Restore
print '\27[?47l'

if retcode ~= 0 then
   error(retcode)
end

print("kthxbye")
return retcode
```

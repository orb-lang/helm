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


--[[

I'll keep this around for a bit, it looks nice


--]]

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
## onkey(err, key)

We buffer escape sequences, which terminate in an alphabetic value.


No special effort to detect "^[[" (as opposed to just "^[") is made, that is
handled at the recognizer layer.


#### onkey state

This is a stateful event loop, no way around it.


State is maintained in the following upvalues.

```lua
local keybuf = {}
local sub, byte = string.sub, string.byte
local concat = table.concat

local linebuf = { line = "",
                  ndx  = 0 }

local max_row, mac_col = 0, 0
local finding_max = false

local function cursor_pos(str)
   str = sub(str, 3, -2)
   local row, col = core.cleave(str, ";")
   return tonumber(row), tonumber(col)
end

local _row = 1
local function colwrite(str)
   local dash = a.stash() .. a.jump(_row, 80) .. str .. a.pop()
   write(dash)
   _row = _row + 1
end

local function process_escapes(seq)
   local term = sub(seq, -1)
   if term == "R" and finding_max then
      max_row, max_col = cursor_pos(seq)
      write(a.pop())
      finding_max = false
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

local function recognize(seq)
   -- This front matter belongs in the escape handling code.
   if byte(seq) == 27 then
      process_escapes(seq)
      return
   end
   write(seq)
end
```
```lua
local function onkey(err, key)
   if err then error(err) end
   -- ^Q to quit
   if key == "\17" then
      femto.cooked()
      uv.stop()
      return 0
   end
   if key == "\27" then
      keybuf[#keybuf + 1]  = key
      return
   end
   if #keybuf > 0 then
      local char = byte(key)
      -- esc [0-9]
      if #keybuf == 1 and
         char >= 48 and char <= 57 then
         local esc_val = "\27" .. key
         keybuf[1] = nil
         return recognize(esc_val)
      end
      -- [A-Za-z]
      if (char >= 65 and char <= 90)
         or (char >= 97 and char <= 122) then
         local esc_val = concat(keybuf) .. key
         for i, _ in ipairs(keybuf) do keybuf[i] = nil end
         return recognize(esc_val)
      else
         keybuf[#keybuf + 1] = key
         return
      end
   end
   return recognize(key)
end
```
```lua
-- Alternate screen

coroutine.wrap(function()
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
      uv.read_start(stdin, onkey)
      finding_max = true
      -- stash cursor
      write(a.stash())
      -- Jump to bottom right and report position.
      write("\27[999C\27[999B\27[6n")
      -- the story continues in onkey...
   else
      uv.read_start(stdin, onread)
   end
end)()



local retcode = uv.run('default')
-- Restore
print '\27[?47l'

if retcode ~= 0 then
   error(retcode)
end

print("kthxbye")
return retcode
```















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











local keybuf = {}
local byte = string.byte
local concat = table.concat

local function recognize(seq)
   uv.write(stdout, seq)
end

local function onkey(err, key)
   if err then error(err) end
   if key == "\17" then
      femto.disableRawMode()
      uv.stop()
      return 0
   end
   if key == "\27" then
      keybuf[#keybuf + 1]  = key
      return
   end
   if #keybuf > 0 then
      local char = byte(key)
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
   femto.enableRawMode()
   uv.read_start(stdin, onkey)
   --uv.read_start(stdin, onread)
end)()



local retcode = uv.run('default')
-- Restore

print '\27[?47l'

print("kthxbye")
return retcode

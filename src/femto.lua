













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










local function cursor_pos(str)
   local row, col = core.cleave(str, ";")
   return tonumber(row), tonumber(col)
end

-- this is exploratory code
local _row = 1
local function colwrite(str)
   local dash = a.stash() .. a.jump(_row, 80) .. str .. a.pop()
   write(dash)
   _row = _row + 1
end

local function process_escapes(seq)
   local term = sub(seq, -1)
   local CSI  = sub(seq, 2, 2) == "[" and true or false
   local payload
   local ltrim = CSI and 3 or 2
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

local function lexer(seq)
   -- This front matter belongs in the escape handling code.
   if byte(seq) == 27 then
      process_escapes(seq)
      return
   end
   write(seq)
end




















































































































































































































































local function isnum(char)
   return char >= "0" and char <= "9"
end

local function isalpha(char)
   return (char >= "A" and char <= "z")
      or  (char >= "a" and char <= "z")
end

local _C1terms = {"D","E","H","M","N","O","V","W","X","Z","]","^"}

local C1Termset = {}

for i = 1, #_C1terms do
   C1Termset[ _C1terms[i]] = true
end

_C1terms = nil


local function C1Terminal(char)
   return C1Termset[char]
end

local function CSIPrequel(char)
   if char == "?" or char == ">" or char == "!" then
      return true
   end
end



-- These state flags should be closed over to make
-- onkey re-entrant.

-- This will allow our parser to be re-used by user
-- programs without interfering with the repl.
--

local escaping = false
local csi      = false
local wchar    = false

local function onkey(err, key)
   if err then error(err) end
   -- ^Q to quit
   if key == "\17" then
      femto.cooked()
      uv.stop()
      return 0
   end
   if key == "\27" then
      escaping = true
      keybuf[#keybuf + 1]  = key
      return
   end
   if escaping then
      if csi then
         -- All CSI parsing
         assert(#keybuf >= 2, "keybuf too small for CSI")
         assert(keybuf[1] == "\27", "keybuf[1] ~= ^[")
         assert(keybuf[2] == "[", "keybuf ~= ^[[")
         if CSIPrequel(key) then
            assert(#keybuf == 2, "CSIPrequel must be keybuf[3]")
            keybuf[3] = key
            return
         end

         if isnum(key) or key == ";" then
            keybuf[#keybuf + 1] = key
            return
         end

         if isalpha(key) or key == "~" then
            escaping, csi = false, false
            local esc_val = concat(keybuf) .. key
            for i = 1, #keybuff do keybuf[i] = nil end
            return lexer(esc_val)
         else
            error("possible invalid during csi parsing: " .. key)
            return
         end
      -- detect CSI
      elseif key == "[" then
         csi = true
         assert(keybuf[2] == nil, "[ was not in CSI position")
         keybuf[2] = key
         return
      elseif C1Terminal(key) then
         -- seq[2]
         assert(keybuf[2] == nil, "CSITerminal with non-nil keybuf[2]")
         escaping = false
         keybuf[1] = nil
         return lexer("\27" .. key)
      else
         -- This is not yet correct!
         keybuf[#keybuf + 1] = key
         return
      end
   elseif not wchar then
      -- if not escaping or wchar then check ASCIIness
      if key <= "~" then
         return lexer(key) -- add some kind of mode parameter
      else
         -- backspace, wchars etc
      end
   end
   return lexer(key)
end



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

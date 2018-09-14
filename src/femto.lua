










__G = setmetatable({}, {__index = _G})

setfenv(0, __G)
local function _femto(_ENV)





setfenv(1, _ENV)
L    = require "lpeg"
lfs  = require "lfs"
ffi  = require "ffi"
bit  = require "bit"
uv   = require "luv"
utf8 = require "lua-utf8"

-- replace string lib with utf8 equivalents
for k,v in pairs(utf8) do
   if string[k] then
      string[k] = v
   end
end

jit.vmdef = require "vmdef"
jit.p = require "ljprof"

-- sqlayer uses this monkey patch:
ffi.reflect = require "reflect"
sql = require "sqlayer"

















core = require "core"
string.cleave, string.litpat = core.cleave, core.litpat
string.utf8 = core.utf8 -- deprecated
string.codepoints = core.codepoints
string.lines = core.lines
table.splice = core.splice
table.clone = core.clone
table.arrayof = core.arrayof
table.collect = core.collect
table.select = core.select
table.reverse = core.reverse
table.hasfield = core.hasfield
table.keys = core.keys

table.pack = rawget(table, "pack") and table.pack or core.pack
table.unpack = rawget(table, "unpack") and table.unpack or unpack

meta = core.meta
getmeta, setmeta = getmetatable, setmetatable
hasmetamethod, hasfield = core.hasmetamethod, core.hasfield
coro = coroutine
assert = core.assertfmt

local concat = assert(table.concat)








a = require "anterm"
color = require "color"
ts = color.ts
c = color.color
watch = require "watcher"










local _log = {}
_log.vals = {}
local format = assert(string.format )
local function __logger(_, fmtstr, ...)
   _log[#_log + 1] = format(fmtstr, ...)
   _log.vals[#_log.vals + 1] = table.pack(...)
end

log = setmeta(_log, {__call = __logger})

log.cache = {}
function cache(a,b,c)
   local tuck = {a,b,c}
   log.cache[#log.cache + 1] = tuck
end







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









-- This switches screens and does a wipe,
-- then puts the cursor at 1,1.
write "\x1b[?47h\x1b[2J\x1b[H"
modeS = require "modeselektor" ()
modeS.max_row, modeS.max_col = uv.tty_get_winsize(stdin)












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
      uv.tty_set_mode(stdin, 1)
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
      -- This also includes pastes, and I should probably
      -- signal the distinction at some point
      return modeS("ASCII", seq)
   else
      -- wchars go here
      return modeS("NYI", seq)
   end
end



-- Get names for as many values as possible
-- into the colorizer
color.allNames()

-- Re-attach _G

--setfenv(0, __G)

print "an repl, plz reply uwu 👀"
write '👉  '

-- raw mode
uv.tty_set_mode(stdin, 2)
-- mouse mode
write(a.mouse.track(true))
uv.read_start(stdin, onseq)



-- main loop
local retcode =  uv.run('default')
-- Restore main screen
print '\x1b[?47l'

if retcode ~= true then
   error(retcode)
end

print("kthxbye")
return retcode







end -- of wrapper
local retcode = _femto(__G)

return retcode

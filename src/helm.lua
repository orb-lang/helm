





if rawget(_G, "_Bridge") then
  _Bridge.helm = true
end












__G = setmetatable({}, {__index = _G})









local function _helm(_ENV)





setfenv(1, _ENV)

L    = require "lpeg"
lfs  = require "lfs"
ffi  = require "ffi"
bit  = require "bit"
uv   = require "luv"
utf8 = require "lua-utf8"
core = require "singletons/core"

jit.vmdef = require "helm:helm/vmdef"
jit.p = require "helm:helm/ljprof"

--apparently this is a hidden, undocumented LuaJIT thing?
require "table.clear"

sql = assert(sql, "sql must be in _G")

















string.cleave, string.litpat = core.cleave, core.litpat
string.utf8 = core.utf8 -- deprecated
string.codepoints = core.codepoints
string.lines = core.lines
table.splice = core.splice
table.clone = core.clone
table.isarray = core.isarray
table.arrayof = core.arrayof
table.collect = core.collect
table.select = core.select
table.reverse = core.reverse
table.hasfield = core.hasfield
table.keys = core.keys
math.bound = core.bound
math.inbounds = core.inbounds

table.pack = rawget(table, "pack") and table.pack or core.pack
table.unpack = rawget(table, "unpack") and table.unpack or unpack

meta = core.meta
getmeta, setmeta = getmetatable, setmetatable
coro = coroutine
--assert = core.assertfmt

local concat = assert(table.concat)





a = require "singletons/anterm"
local repr = require "helm/repr"
--watch = require "watcher"







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








-- Get window size and set up an idler to keep it refreshed

local max_col, max_row = uv.tty_get_winsize(stdin)

modeS = require "helm/modeselektor" (max_col, max_row)

local insert = assert(table.insert)
local function s_out(msg)
  insert(modeS.status, msg)
end

-- make a new 'status' instance
local s = require "singletons/status" (s_out)

local timer = uv.new_timer()
uv.timer_start(timer, 500, 500, function()
   max_col, max_row = uv.tty_get_winsize(stdin)
   if max_col ~= modeS.max_col or max_row ~= modeS.max_row then
      -- reflow screen.
      modeS.max_col, modeS.max_row = max_col, max_row
      modeS:reflow()
   end
end)












local byte, sub, codepoints, char = assert(string.byte),
                                    assert(string.sub),
                                    assert(string.codepoints),
                                    assert(string.char)
local m_parse, is_mouse = a.mouse.parse_fast, a.mouse.ismousemove
local navigation, is_nav = a.navigation, a.is_nav

local function process_escapes(seq)
   if is_nav(seq) then
      return modeS("NAV", navigation[seq])
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

-- uv, being an event loop, will sometimes keep reading after
-- we expect it to stop.
-- this prevents modeS from being reloaded in such circumstances.
--
-- maybe.

local _ditch = false

local function onseq(err,seq)
   if _ditch then return nil end
   if err then error(err) end

   local head = byte(seq)
   -- ^Q hard coded as quit, for now
   if head == 17 then
      _ditch = true
      modeS.zones.status:replace 'exiting repl, owo... 🐲'
      modeS:paint()
      uv.read_stop(stdin)
      uv.timer_stop(timer)
      return 0
   end
   -- Escape sequences
   if head == 27 then
      return process_escapes(seq)
   end
   -- Control sequences
   if navigation[seq] then
      return modeS("NAV", navigation[seq])
    elseif head <= 31 then
      local ctrl = "^" .. char(head + 64)
      return modeS("CTRL", ctrl)
   end
   -- Printables
   if head > 31 and head < 127 then
      if #seq > 1 then
         -- break it up and feed it
         local points = codepoints(seq)
         for _, pt in ipairs(points) do
            onseq(nil, pt)
         end
      else
         return modeS("ASCII", seq)
      end
   else
      -- wchars go here
      return modeS("UTF8", seq)
   end
end





-- Get names for as many values as possible
-- into the colorizer
repr.allNames(__G)

-- assuming we survived that, set up our repling environment:

-- raw mode
uv.tty_set_mode(stdin, 2)

-- mouse mode
write(a.mouse.track(true))
uv.read_start(stdin, onseq)

-- This saves the cursor, switches screens and does a wipe,
-- then puts the cursor at 1,1.
-- #todo Cursor save/restore supposedly may not work on all terminals?
-- Test this and, if necessary, explicitly read and store the cursor position
-- and manually restore it at the end.
-- #todo Implement this in terms of anterm functions
write("\x1b7\x1b[?47h\x1b[2J\x1b[H")

-- paint screen
modeS:paint()

-- main loop
local retcode =  uv.run('default')

-- Mouse tracking off
io.write(a.mouse.track(false))

-- Restore main screen and cursor
io.write('\x1b[?47l\x1b8')

-- remove any spurious mouse inputs or other stdin stuff
io.stdin:read "*a"

-- Back to normal mode
uv.tty_reset_mode()

uv.stop()

io.stdout:flush()

end -- of _helm





return _helm

# Helm


``helm`` is our repl.

```lua
if rawget(_G, "_Bridge") then
  _Bridge.helm = true
end
```
#### Intercept _G

We don't want to put ``helm`` into the environment of the codebase under
examination, so we replace the global environment with a table which falls
back to ``_G``.


Man.  I really like having first-class environments.

```lua
__G = setmetatable({}, {__index = _G})

setfenv(0, __G)
```

Let's wedge in the argparse where it won't break between bridge builds:

```lua
--[[
brParse
   : name "bridge"
   : description "An lua, howth castle & environs."
   : epilog "For more info, see https://specialcircumstanc.es"
   : require_command(false)
   : command_target "verb"
   : command ("orb o", "orb compiler", "orb subcommands")
   : argument ("serve s", "launch localhost responsive compiler and document server")
   : parse()
--]]
```
```lua
local function _helm(_ENV)
```

No sense wasting a level of indent on a wrapper imho

```lua
setfenv(1, _ENV)

L    = require "lpeg"
lfs  = require "lfs"
ffi  = require "ffi"
bit  = require "bit"
uv   = require "luv"
utf8 = require "lua-utf8"
core = require "singletons/core"

-- replace string lib with utf8 equivalents
for k,v in pairs(utf8) do
   if string[k] then
      string[k] = v
   end
end

jit.vmdef = require "vmdef"
jit.p = require "ljprof"

--apparently this is a hidden, undocumented LuaJIT thing?
require "table.clear"

sql = assert(sql, "sql must be in _G")
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
readOnly = core.readOnly
coro = coroutine
--assert = core.assertfmt

local concat = assert(table.concat)
```

Primitives for terminal manipulation.

```lua
a = require "singletons/anterm"
local repr = require "helm/repr"
--watch = require "watcher"

```
### Logging

I'm making the crudest possible logger here.


This thing sucks tbh, don't think I'm using it and should probably delete.

```lua
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

```

This boot sequence builds on Tim Caswell and the Luvit Author's repl example.


Couple pieces I'm not using but should:
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
   ts = tostring
   -- #todo make this properly black and white ts
end
```

Not-blocking ``write`` and ``print``:

```lua
function write(str)
   uv.write(stdout, str)
end
```
```lua
function print(...)
  local n = select('#', ...)
  local arguments = {...}
  for i = 1, n do
    arguments[i] = tostring(arguments[i])
  end
  uv.write(stdout, concat(arguments, "\t") .. "\n")
end
```
### tty setup

```lua
if uv.guess_handle(0) ~= "tty" or
   uv.guess_handle(1) ~= "tty" then
  -- Entry point for other consumers!
  error "stdio must be a tty"
end

local stdin = uv.new_tty(0, true)
```
## Modeselektor


```lua

-- Get window size and set up an idler to keep it refreshed

local max_col, max_row = uv.tty_get_winsize(stdin)

modeS = require "helm/modeselektor" (max_col, max_row)

local function s_out(msg)
  insert(modeS.status, msg)
end

-- make a new 'status' instance
local s = require "status" (s_out)

local timer = uv.new_timer()
uv.timer_start(timer, 500, 500, function()
   max_col, max_row = uv.tty_get_winsize(stdin)
   if max_col ~= modeS.max_col or max_row ~= modeS.max_row then
      -- reflow screen.
      modeS.max_col, modeS.max_row = max_col, max_row
      modeS:reflow()
   end
end)
```
## Reader

The reader takes a stream of data from ``stdin``, asynchronously, and
processes it into tokens, which stream to the ``modeselektor``.


### process_escapes(seq)

```lua
local byte, sub, codepoints = string.byte, string.sub, string.codepoints
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
      return modeS("NYI", seq)
   end
end
```
```lua

--[[ read main programme
if arg[1] then
  local prog = table.remove(arg, 1)
  local chunk, err = loadfile(prog)
  if chunk then
     setfenv(chunk, _G)()
  else
     error ("couldn't load " .. prog .. "\n" .. err)
  end
end
--]]



-- Get names for as many values as possible
-- into the colorizer
repr.allNames(_G)

-- assuming we survived that, set up our repling environment:

-- raw mode
uv.tty_set_mode(stdin, 2)

-- mouse mode
write(a.mouse.track(true))
uv.read_start(stdin, onseq)

-- #todo This should start with a read which saves the cursor location.
-- This switches screens and does a wipe,
-- then puts the cursor at 1,1.
write "\x1b[?47h\x1b[2J\x1b[H"

-- paint screen
modeS:paint()

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
#### Launch helm

Here we assign our function a wrapper and get down to business

```lua
end -- of wrapper
local retcode = _helm(__G)

return retcode
```

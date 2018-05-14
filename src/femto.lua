









local sql = require "sqlite"

local lfs = require "lfs"
local ffi = require "ffi"

local femto = assert(femto)

local uv = require "luv"

local L = require "lpeg"

local a = require "src/anterm"

local c = require "src/color"

--  **** utils
--
--  Copypasta from luvland from here down

local usecolors
local stdout

if uv.guess_handle(1) == "tty" then
  stdout = uv.new_tty(1, false)
  usecolors = true
else
  utils.stdout = uv.new_pipe(false)
  uv.pipe_open(utils.stdout, 1)
  usecolors = false
end

-- Print replacement that goes through libuv.  This is useful on windows
-- to use libuv's code to translate ansi escape codes to windows API calls.
local function print(...)
  local n = select('#', ...)
  local arguments = {...}
  for i = 1, n do
    arguments[i] = tostring(arguments[i])
  end
  uv.write(stdout, table.concat(arguments, "\t") .. "\n")
end

local function write(str)
   uv.write(stdout, str)
end


--  *** tty setup

if uv.guess_handle(0) ~= "tty" or
   uv.guess_handle(1) ~= "tty" then
  -- Entry point for other consumers!
  error "stdio must be a tty"
end

local stdin = uv.new_tty(0, true)

-- **** colorizer

-- This will be the first thing to go

local colors = {
  black   = "0;30",
  red     = "0;31",
  green   = "0;32",
  yellow  = "0;33",
  blue    = "0;34",
  magenta = "0;35",
  cyan    = "0;36",
  white   = "0;37",
  B        = "1;",
  Bblack   = "1;30",
  Bred     = "1;31",
  Bgreen   = "1;32",
  Byellow  = "1;33",
  Bblue    = "1;34",
  Bmagenta = "1;35",
  Bcyan    = "1;36",
  Bwhite   = "1;37"
}

local function color(color_name)
  if usecolors then
    return "\27[" .. (colors[color_name] or "0") .. "m"
  else
    return ""
  end
end

local function colorize(color_name, string, reset_name)
  return color(color_name) .. tostring(string) .. color(reset_name)
end

local backslash, null, newline, carriage, tab, quote, quote2, obracket, cbracket

local function loadColors(n)
  if n ~= nil then usecolors = n end
  backslash = colorize("Bgreen", "\\\\", "green")
  null      = colorize("Bgreen", "\\0", "green")
  newline   = colorize("Bgreen", "\\n", "green")
  carriage  = colorize("Bgreen", "\\r", "green")
  tab       = colorize("Bgreen", "\\t", "green")
  quote     = colorize("Bgreen", '"', "green")
  quote2    = colorize("Bgreen", '"')
  obracket  = colorize("B", '[')
  cbracket  = colorize("B", ']')
end

loadColors()

local gsub = string.gsub

local function dump(o, depth)
  local t = type(o)
  if t == 'string' then
    return quote .. o:gsub("\\", backslash)
                     :gsub("%z", null)
                     :gsub("\n", newline)
                     :gsub("\r", carriage)
                     :gsub("\t", tab) .. quote2
  end
  if t == 'nil' then
    return colorize("Bblack", "nil")
  end
  if t == 'boolean' then
    return colorize("yellow", tostring(o))
  end
  if t == 'number' then
    return colorize("blue", tostring(o))
  end
  if t == 'userdata' then
    return colorize("magenta", tostring(o))
  end
  if t == 'thread' then
    return colorize("Bred", tostring(o))
  end
  if t == 'function' then
    return colorize("cyan", tostring(o))
  end
  if t == 'cdata' then
    return colorize("Bmagenta", tostring(o))
  end
  if t == 'table' then
    if type(depth) == 'nil' then
      depth = 0
    end
    if depth > 1 then
      return colorize("yellow", tostring(o))
    end
    local indent = ("  "):rep(depth)
    -- Check to see if this is an array
    local is_array = true
    local i = 1
    for k,v in pairs(o) do
      if not (k == i) then
        is_array = false
      end
      i = i + 1
    end

    local first = true
    local lines = {}
    i = 1
    local estimated = 0
    for k,v in (is_array and ipairs or pairs)(o) do
      local s
      if is_array then
        s = ""
      else
        if type(k) == "string" and k:find("^[%a_][%a%d_]*$") then
          s = k .. ' = '
        else
          s = '[' .. dump(k, 100) .. '] = '
        end
      end
      s = s .. dump(v, depth + 1)
      lines[i] = s
      estimated = estimated + #s
      i = i + 1
    end
    if estimated > 200 then
      return "{\n  " .. indent
         .. table.concat(lines, ",\n  " .. indent)
         .. "\n" .. indent .. "}"
    else
      return "{ " .. table.concat(lines, ", ") .. " }"
    end
  end
end

local clr = color


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
  if line == "<3\n" then
    print("I " .. clr("Bred") .. "♥" .. clr() .. " you too!")
    return '>'
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

  return '👉 '
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

-- Alternate screen

coroutine.wrap(function()
   -- This switches screens and does a wipe,
   -- then puts the cursor at 1,1.
   write '\27[?47h\27[2J\27[H'
   print "an repl, plz reply uwu 👀"
   displayPrompt '👉 '
   uv.read_start(stdin, onread)
end)()

uv.run('default')

-- Restore

print '\27[?47l'

print("kthxbye")
return 0

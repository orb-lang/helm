













sql = require "sqlite"

lfs = require "lfs"
ffi = require "ffi"

uv = require "luv"

L = require "lpeg"

a = require "src/anterm"

c = require "src/color"

watch = require "src/watcher"







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
  if line == "<3\n" then
    print("I " .. a.red("♥") .. " you too!")
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

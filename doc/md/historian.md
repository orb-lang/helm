# Historian


This module is responsible for REPL history.


Eventually this will include persisting and restoring from a SQLite database,
fuzzy searching, and variable cacheing.


Currently does the basic job of retaining history and not letting subsequent
edits munge it.


Next step: now that we clone a new linebuf each time, we have an immutable
record.  We should store the line as a string, to facilitate fuzzy matching.


```lua
local Linebuf = require "linebuf"
local sql     = require "sqlayer"
local L       = require "lpeg"
local format  = assert (string.format)
local sub     = assert (string.sub)
assert(meta)
```
```lua
local Historian = meta {}
```
## Historian:load()

This is where we either create query or create our ``~/.bridge`` database.

```lua
Historian.HISTORY_LIMIT = 1000

local create_repl_table = [[
CREATE TABLE IF NOT EXISTS repl (
line_id INTEGER PRIMARY KEY AUTOINCREMENT,
project TEXT,
line TEXT,
time DATETIME DEFAULT CURRENT_TIMESTAMP);
]]

local insert_line_stmt = [[
INSERT INTO repl (project, line) VALUES(:project, :line);
]]

local get_tables = [[
SELECT name FROM sqlite_master WHERE type='table';
]]

local get_recent = [[
SELECT line FROM repl
   WHERE project = %s
   ORDER BY time
   DESC LIMIT %d;
]]

Historian.home_dir = io.popen("echo $HOME", "r"):read("*a"):sub(1, -2)
Historian.project = io.popen("pwd", "r"):read("*a"):sub(1, -2)

local function has(table, name)
   for _,v in ipairs(table) do
      if name == v then
         return true
      end
   end
   return false
end
```
## Historian:search(frag)

```lua
local P, match = L.P, L.match

-- second_best is broke and I don't know why
-- also this fails on a single key search >.<
local function fuzz_patt(frag)
   frag = type(frag) == "string" and codepoints(frag) or frag
   local patt =        (P(1) - P(frag[1]))^0
   for i = 1 , #frag - 1 do
      local v = frag[i]
      patt = patt * (P(v) * (P(1) - P(frag[i + 1]))^0)
   end
   patt = patt * P(frag[#frag])
   return patt
end

function Historian.search(historian, frag)
   local collection = {}
   local best = true
   local patt = fuzz_patt(frag)
   for i = #historian, 1, -1 do
      local score = match(patt, tostring(historian[i]))
      if score then
         collection[#collection + 1] = tostring(historian[i])
      end
   end
   local slip = ""
   if #collection == 0 then
      -- try the transpose
      best = false
      slip = sub(frag, 1, -3) .. sub(frag, -1, -1) .. sub(frag, -2, -2)
      local second = fuzz_patt(slip)
      for i = #historian, 1, -1 do
         local score = match(second, tostring(historian[i]))
         if score then
            collection[#collection + 1] = tostring(historian[i])
         end
      end
   end

   return collection, best, slip
end
```
```lua
local reverse = assert(table.reverse)

function Historian.load(historian)
   local conn = sql.open(historian.home_dir .. "/.bridge")
   historian.conn = conn
   local table_names = conn:exec(get_tables)
   if not table_names or not has(table_names.name, "repl") then
      local success, err = sql.pexec(conn, create_repl_table)
      -- success is nil for creation, false for error
      if success == false then
         error(err)
      end
   end
   historian.insert_stmt = conn:prepare(insert_line_stmt)
   local pop_stmt = sql.format(get_recent, historian.project,
                        historian.HISTORY_LIMIT)
   local values, err = sql.pexec(conn, pop_stmt)
   if values then
      for i,v in ipairs(reverse(values[1])) do
         historian[i] = Linebuf(v)
      end
      historian.cursor = #historian
      historian.up = false
   end
end

function Historian.persist(historian, linebuf)
   local lb = tostring(linebuf)
   historian.insert_stmt:bindkv { project = historian.project,
                                  line    = lb }
   local err = historian.insert_stmt:step()
   if not err then
      historian.insert_stmt:clearbind():reset()
   else
      error(error)
   end
   return true
end
```
## Historian:prev()

```lua
function Historian.prev(historian)
   if historian.cursor == 0 then
      return Linebuf()
   end
   local Δ = historian.cursor > 1 and 1 or 0
   local linebuf = historian[historian.cursor - Δ]
   local result = historian.results[linebuf]
   historian.cursor = historian.cursor - Δ
   linebuf.cursor = #linebuf.line + 1
   return linebuf:clone(), result
end
```
### Historian:next()

Returns the next linebuf in history, and a second flag to tell the
``modeselektor`` it might be time for a new one.

```lua
function Historian.next(historian)
   local Δ = historian.cursor < #historian and 1 or 0
   if historian.cursor == 0 then
      return Linebuf()
   end
   local linebuf= historian[historian.cursor + Δ]
   local result = historian.results[linebuf]
   historian.cursor = historian.cursor + Δ
   linebuf.cursor = #linebuf.line + 1
   if not (Δ > 0) and #linebuf.line > 0 then
      return linebuf:clone(), result, true
   else
      return linebuf:clone(), result, false
   end
end
```
### Historian:append()

```lua
function Historian.append(historian, linebuf)
   historian[#historian + 1] = linebuf
   historian.cursor = #historian
   historian:persist(linebuf)
   return true
end
```
```lua
local function new()
   local historian = meta(Historian)
   historian:load()
   -- This will also be load()ed once we have the tables for it
   historian.results = {} -- keyed by linebuf
   return historian
end
Historian.idEst = new
```
```lua
return new
```

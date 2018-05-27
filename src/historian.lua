















local Linebuf = require "linebuf"
local sql     = require "sqlayer"
local color   = require "color"
local L       = require "lpeg"
local format  = assert (string.format)
local sub     = assert (string.sub)
local reverse = assert (table.reverse)
assert(meta)



local Historian = meta {}

































Historian.HISTORY_LIMIT = 1000

local create_repl_table = [[
CREATE TABLE IF NOT EXISTS repl (
line_id INTEGER PRIMARY KEY AUTOINCREMENT,
project TEXT,
line TEXT,
time DATETIME DEFAULT CURRENT_TIMESTAMP);
]]

local create_result_table = [[
CREATE TABLE IF NOT EXISTS results (
result_id INTEGER PRIMARY KEY AUTOINCREMENT,
line_id INTEGER,
repr text NOT NULL,
value blob,
FOREIGN KEY (line_id)
   REFERENCES repl (line_id)
   ON DELETE CASCADE);
]]

local insert_line_stmt = [[
INSERT INTO repl (project, line) VALUES (:project, :line);
]]

local insert_result_stmt = [[
INSERT INTO results (line_id, repr) VALUES (:line_id, :repr);
]]

local get_tables = [[
SELECT name FROM sqlite_master WHERE type='table';
]]

local get_recent = [[
SELECT CAST (line_id AS REAL), line FROM repl
   WHERE project = %s
   ORDER BY time
   DESC LIMIT %d;
]]

local get_recent_2 = [[
SELECT CAST (repl.line_id AS REAL), results.repr
FROM repl
LEFT OUTER JOIN results
ON repl.line_id = results.line_id
WHERE repl.project = '%s'
ORDER BY repl.time
DESC LIMIT %d;
]]

local home_dir = io.popen("echo $HOME", "r"):read("*a"):sub(1, -2)

local bridge_home = io.popen("echo $BRIDGE_HOME", "r"):read("*a"):sub(1, -2)
Historian.bridge_home = bridge_home ~= "" and bridge_home
                        or home_dir .. "/.bridge"

Historian.project = io.popen("pwd", "r"):read("*a"):sub(1, -2)

local function has(table, name)
   for _,v in ipairs(table) do
      if name == v then
         return true
      end
   end
   return false
end








function Historian.load(historian)
   local conn = sql.open(historian.bridge_home)
   historian.conn = conn
   conn:exec "PRAGMA foreign_keys = ON;"
   conn:exec(create_result_table)
   local success, err = sql.pexec(conn, create_repl_table)
   -- success is nil for creation, false for error
   if success == false then
      error(err)
   end
   historian.insert_line_stmt = conn:prepare(insert_line_stmt)
   historian.insert_result_stmt = conn:prepare(insert_result_stmt)
   local pop_stmt = sql.format(get_recent, historian.project,
                        historian.HISTORY_LIMIT)
   local values, err = sql.pexec(conn, pop_stmt, "i")
   if values then
      for i, v in ipairs(reverse(values[2])) do
         historian[i] = Linebuf(v)
      end
      historian.cursor = #historian
      historian.up = false
   end
end



















function Historian.persist(historian, linebuf, results)
   local lb = tostring(linebuf)
   if lb ~= "" then
      historian.insert_line_stmt:bindkv { project = historian.project,
                                     line    = lb }
      local err = historian.insert_line_stmt:step()
      if not err then
         historian.insert_line_stmt:clearbind():reset()
      else
         error(err)
      end
      local line_id = sql.lastRowId(historian.conn)
      if results and type(results) == "table" then
         for _,v in ipairs(results) do
            -- insert result repr
            -- tostring() just for compactness
            historian.insert_result_stmt:bindkv { line_id = line_id,
                                                  repr = tostring(v) }
            err = historian.insert_result_stmt:step()
            if not err then
               historian.insert_result_stmt:clearbind():reset()
            end
         end
      end

   return true
   else
      -- A blank line can have no results and is uninteresting.
      return false
   end
end






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
   if #collection == 0 then
      -- try the transpose
      best = false
      local slip = sub(frag, 1, -3) .. sub(frag, -1, -1) .. sub(frag, -2, -2)
      local second = fuzz_patt(slip)
      for i = #historian, 1, -1 do
         local score = match(second, tostring(historian[i]))
         if score then
            collection[#collection + 1] = tostring(historian[i])
         end
      end
   end

   return collection, best
end






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











function Historian.next(historian)
   local Δ = historian.cursor < #historian and 1 or 0
   if historian.cursor == 0 then
      return Linebuf()
   end
   local linebuf= historian[historian.cursor + Δ]
   local result = historian.results[linebuf]
   if not linebuf then
      return Linebuf()
   end
   historian.cursor = historian.cursor + Δ
   linebuf.cursor = #linebuf.line + 1
   if not (Δ > 0) and #linebuf.line > 0 then
      historian.cursor = #historian + 1
      return linebuf:clone(), nil, true
   else
      return linebuf:clone(), result, false
   end
end






function Historian.append(historian, linebuf, results)
   historian[#historian + 1] = linebuf
   historian.cursor = #historian
   historian:persist(linebuf, results)
   return true
end



local function new()
   local historian = meta(Historian)
   historian:load()
   -- This will also be load()ed once we have the tables for it
   historian.results = {} -- keyed by linebuf
   return historian
end
Historian.idEst = new



return new

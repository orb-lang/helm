















local L       = require "lpeg"
local uv      = require "luv"
local sql     = assert(sql, "sql must be in bridge _G")

local Txtbuf  = require "helm/txtbuf"
local Rainbuf = require "helm/rainbuf"
local c       = import("singletons/color", "color")
local repr    = require "helm/repr"
local Codepoints = require "singletons/codepoints"

local concat = assert(table.concat)
local reverse = import("core/table", "reverse")



local Historian = meta {}










Historian.HISTORY_LIMIT = 2000

local create_project_table = [[
CREATE TABLE IF NOT EXISTS project (
   project_id INTEGER PRIMARY KEY AUTOINCREMENT,
   directory TEXT UNIQUE,
   time DATETIME DEFAULT CURRENT_TIMESTAMP
);
]]

local create_repl_table = [[
CREATE TABLE IF NOT EXISTS repl (
   line_id INTEGER PRIMARY KEY AUTOINCREMENT,
   project INTEGER,
   line TEXT,
   time DATETIME DEFAULT CURRENT_TIMESTAMP,
   FOREIGN KEY (project)
      REFERENCES project (project_id)
      ON DELETE CASCADE
);
]]

local create_result_table = [[
CREATE TABLE IF NOT EXISTS result (
   result_id INTEGER PRIMARY KEY AUTOINCREMENT,
   line_id INTEGER,
   repr text NOT NULL,
   value blob,
   FOREIGN KEY (line_id)
      REFERENCES repl (line_id)
      ON DELETE CASCADE
);
]]

local create_session_table = [[
CREATE TABLE IF NOT EXISTS session (
session_id INTEGER PRIMARY KEY AUTOINCREMENT,
name TEXT,
project INTEGER,
-- These two are line_ids
start INTEGER NOT NULL,
end INTEGER,
test BOOLEAN,
sha TEXT,
FOREIGN KEY (project)
   REFERENCES project (project_id)
   ON DELETE CASCADE );
]]

local insert_line = [[
INSERT INTO repl (project, line) VALUES (:project, :line);
]]

local insert_result = [[
INSERT INTO result (line_id, repr) VALUES (:line_id, :repr);
]]

local insert_project = [[
INSERT INTO project (directory) VALUES (?);
]]

local get_recent = [[
SELECT CAST (line_id AS REAL), line FROM repl
   WHERE project = :project
   ORDER BY time DESC
   LIMIT :num_lines;
]]

local get_number_of_lines = [[
SELECT CAST (count(line) AS REAL) from repl
   WHERE project = ?
;
]]

local get_project = [[
SELECT project_id FROM project
   WHERE directory = %s;
]]

local get_results = [[
SELECT result.repr
FROM result
WHERE result.line_id = :line_id
ORDER BY result.result_id;
]]

Historian.helm_db = _Bridge.bridge_home .. "/.helm"

Historian.project = uv.cwd()

local function has(table, name)
   for _,v in ipairs(table) do
      if name == v then
         return true
      end
   end
   return false
end















local core_math = require "core/math"
local bound = assert(core_math.bound)

function Historian.load(historian)
   local conn = sql.open(historian.helm_db)
   historian.conn = conn
   -- Set up bridge tables
   conn.pragma.foreign_keys(true)
   conn.pragma.journal_mode "wal"
   conn:exec(create_project_table)
   conn:exec(create_result_table)
   conn:exec(create_repl_table)
   conn:exec(create_session_table)
   -- Retrive project id
   local proj_val, proj_row = sql.pexec(conn,
                                  sql.format(get_project, historian.project),
                                  "i")
   if not proj_val then
      local ins_proj_stmt = conn:prepare(insert_project)
      ins_proj_stmt : bind(historian.project)
      proj_val, proj_row = ins_proj_stmt:step()
      -- retry
      proj_val, proj_row = sql.pexec(conn,
                              sql.format(get_project, historian.project),
                              "i")
      if not proj_val then
         error "Could not create project in .bridge"
      end
   end

   local project_id = proj_val[1][1]
   historian.project_id = project_id
   -- Create insert prepared statements
   historian.insert_line = conn:prepare(insert_line)
   historian.insert_result = conn:prepare(insert_result)
   -- Create result retrieval prepared statement
   historian.get_results = conn:prepare(get_results)
   -- Retrieve history
   local number_of_lines = conn:prepare(get_number_of_lines)
                             :bind(project_id):step()[1]
   if number_of_lines == 0 then
      return nil
   end
   number_of_lines = bound(number_of_lines, nil, historian.HISTORY_LIMIT)
   local pop_stmt = conn:prepare(get_recent)
                      : bindkv { project = project_id,
                                 num_lines = number_of_lines }
   historian.cursor = number_of_lines + 1
   historian.n = number_of_lines
   local counter = number_of_lines
   local idler
   local function load_one()
      local res = pop_stmt:step()
      if not res then
         if idler then idler:stop() end
         return nil
      end
      historian[counter] = Txtbuf(res[2])
      historian.line_ids[counter] = res[1]
      -- Results are loaded *backward* so the most recent one is available ASAP
      counter = counter - 1
   end
   -- add one line to ensure we have history on startup
   load_one()
   -- idle to populate the rest of the history
   idler = uv.new_idle()
   idler:start(load_one)
end


































local insert = assert(table.insert)

function Historian.persist(historian, txtbuf, results)
   local lb = tostring(txtbuf)
   local have_results = results
                        and type(results) == "table"
                        and results.n
   if lb == "" then
      -- A blank line can have no results and is uninteresting.
      return false
   end
   local persist_idler = uv.new_idle()
   local results_tostring, results_lineGens = {}, {}
   if have_results then
      for i = 1, results.n do
         results_lineGens[i] = repr.lineGenBW(results[i])
         results_tostring[i] = {}
      end
   end
   local i = 1
   persist_idler:start(function()
      while have_results and i <= results.n do
         local success, line = pcall(results_lineGens[i])
         if success and line then
            insert(results_tostring[i], line)
         else
            results_tostring[i] = concat(results_tostring[i], "\n")
            i = i + 1
            if not success then
               error(line)
            end
         end
         return nil
      end
      -- now persist
      historian.conn:exec "BEGIN TRANSACTION;"
      historian.insert_line:bindkv { project = historian.project_id,
                                          line    = lb }
      local err = historian.insert_line:step()
      if not err then
         historian.insert_line:clearbind():reset()
      else
         error(err)
      end
      local line_id = sql.lastRowId(historian.conn)
      insert(historian.line_ids, line_id)
      if have_results then
         for i = 1, results.n do
            historian.insert_result:bindkv { line_id = line_id,
                                             repr = results_tostring[i] }
            err = historian.insert_result:step()
            if not err then
               historian.insert_result:clearbind():reset()
            else
               error(err)
            end
         end
      end
      historian.conn:exec "END TRANSACTION;"
      persist_idler:stop()
   end)
   return true
end























local P, match = L.P, L.match

local function fuzz_patt(frag)
   frag = type(frag) == "string" and Codepoints(frag) or frag
   local patt =  (P(1) - P(frag[1]))^0
   for i = 1 , #frag - 1 do
      local v = frag[i]
      patt = patt * (P(v) * (P(1) - P(frag[i + 1]))^0)
   end
   patt = patt * P(frag[#frag])
   return patt
end


























local SelectionList = require "helm/selection_list"
local insert, remove = assert(table.insert), assert(table.remove)
-- local insert, remove = import("core/table", "ninsert", "nremove")

function Historian.search(historian, frag)
   if historian.last_collection
      and historian.last_collection[1].lit_frag == frag then
      -- don't repeat a search
      return historian.last_collection
   end
   if frag == "" then
      return ""
   end
   local result = SelectionList()
   result.cursors = {}
   result.frag = frag
   result.lit_frag = frag
   result.best = true
   result.show_shortcuts = true
   local function try_search()
      local patt = fuzz_patt(result.frag)
      local dup = {}
      for i = historian.n, 1, -1 do
         local item_str = tostring(historian[i])
         if not dup[item_str] and match(patt, item_str) then
            dup[item_str] = true
            insert(result, item_str)
            insert(result.cursors, i)
         end
      end
   end
   try_search()
   if #result == 0 then
      result.best = false
      result.frag = frag:sub(1, -3) .. frag:sub(-1, -1) .. frag:sub(-2, -2)
      try_search()
   end
   result.selected_index = 1
   historian.last_collection = Rainbuf {[1] = result, n = 1, live = true}
   historian.last_collection.made_in = "historian.search"
   return historian.last_collection
end








local lines = import("core/string", "lines")
local function _db_result__repr(result)
   local result_iter = lines(result[1])
   return function()
      local line = result_iter()
      if line then
         return c.greyscale(line)
      else
         return nil
      end
   end
end

local _db_result_M = meta {}
_db_result_M.__repr = _db_result__repr


local function _resultsFrom(historian, cursor)
   if historian.result_buffer[cursor] then
      return historian.result_buffer[cursor]
   end
   local line_id = historian.line_ids[cursor]
   local stmt = historian.get_results
   stmt:bindkv {line_id = line_id}
   local results = stmt:resultset()
   if results then
      results = results[1]
      results.n = #results
      for i = 1, results.n do
         -- stick the result in a table to enable repr-ing
         results[i] = {results[i]}
         setmetatable(results[i], _db_result_M)
      end
   end
   historian.get_results:reset()
   -- may as well memoize the database call, while we're here
   historian.result_buffer[line_id] = results
   return results
end







function Historian.prev(historian)
   historian.cursor = bound(historian.cursor - 1, 1)
   local txtbuf = historian[historian.cursor]
   if txtbuf then
      txtbuf = txtbuf:clone()
      txtbuf:startOfText()
      txtbuf:endOfLine()
      local result = _resultsFrom(historian, historian.cursor)
      return txtbuf, result
   else
      return Txtbuf(), nil
   end
end










function Historian.next(historian)
   historian.cursor = bound(historian.cursor + 1, nil, historian.n + 1)
   local txtbuf = historian[historian.cursor]
   if txtbuf then
      txtbuf = txtbuf:clone()
      txtbuf:endOfText()
      local result = _resultsFrom(historian, historian.cursor)
      return txtbuf, result
   else
      return nil, nil
   end
end









local inbounds = assert(core_math.inbounds)

function Historian.index(historian, cursor)
   assert(inbounds(cursor, 1, historian.n))
   local txtbuf = historian[cursor]:clone()
   txtbuf:endOfText()
   local result = _resultsFrom(historian, cursor)
   historian.cursor = cursor
   return txtbuf, result
end









function Historian.append(historian, txtbuf, results, success)
   if tostring(historian[historian.n]) == tostring(txtbuf)
      or tostring(txtbuf) == "" then
      -- don't bother
      return false
   end
   historian[historian.n + 1] = txtbuf
   historian.n = historian.n + 1
   if success then
      historian:persist(txtbuf, results)
   else
      historian:persist(txtbuf)
   end
   return true
end




local __result_buffer_M = meta {}
function __result_buffer_M.__repr()
   return c.alert "cowardly refusing to print result_buffer to avoid infinite appending"
end

local function new()
   local historian = meta(Historian)
   historian.line_ids = {}
   historian.cursor = 0
   historian.n = 0
   historian:load()
   historian.result_buffer = setmetatable({}, __result_buffer_M)
   return historian
end
Historian.idEst = new



return new

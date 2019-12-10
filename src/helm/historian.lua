















local L       = require "lpeg"
local uv      = require "luv"
local sql     = assert(sql, "sql must be in bridge _G")

local Txtbuf  = require "helm/txtbuf"
local Rainbuf = require "helm/rainbuf"
local c       = (require "singletons/color").color
local repr    = require "helm/repr"
local Codepoints = require "singletons/codepoints"

local concat, reverse         = assert(table.concat), assert(table.reverse)
assert(meta)



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
   ORDER BY time
   DESC LIMIT :num_lines;
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

local home_dir = os.getenv "HOME"
Historian.helm_db = _Bridge.bridge_home .. "/.helm"
-- This require the bridge_home function in pylon, which I can't recompile
-- without github access and I'm on a plane:
-- _Bridge.bridge_home() .. ".helm"

Historian.project = uv.cwd()

local function has(table, name)
   for _,v in ipairs(table) do
      if name == v then
         return true
      end
   end
   return false
end














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
   number_of_lines = historian.HISTORY_LIMIT <= number_of_lines
                     and historian.HISTORY_LIMIT or number_of_lines
   local pop_stmt = conn:prepare(get_recent)
                      : bindkv { project = project_id,
                                 num_lines = number_of_lines }
   -- local recents  = pop_stmt:resultset("i")
   local res = pop_stmt:step()
   if not res then
      return nil
   end
   -- put the results in *backward*
   historian.cursor = number_of_lines
   historian.n = number_of_lines
   local counter = number_of_lines
   -- add one line to ensure we have history on startup
   historian[counter] = Txtbuf(res[2])
   historian.line_ids[counter] = res[1]
   counter = counter - 1
   -- idle to populate the rest of the history
   local idler = uv.new_idle()
   idler:start(function()
      res = pop_stmt:step()
      if res == nil then
         idler:stop()
         return nil
      end
      historian[counter] = Txtbuf(res[2])
      historian.line_ids[counter] = res[1]
      counter = counter - 1
   end)
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
         assert(type(results_lineGens[i]) == 'function')
         results_tostring[i] = {}
      end
   end
   local i = 1
   persist_idler:start(function()
      while have_results and i <= results.n do
         local line = results_lineGens[i]()
         if line then
            insert(results_tostring[i], line)
            return nil
         else
            results_tostring[i] = concat(results_tostring[i], "\n")
            i = i + 1
            return nil
         end
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














local function _highlight(line, frag, best, max_disp, c)
   local frag_index = 1
   -- Collapse multiple spaces into one for display
   line = line:gsub(" +"," ")
   local codes = Codepoints(line)
   local disp = 0
   local stop_at
   for i, char in ipairs(codes) do
      local char_disp = 1
      if char == "\n" then
         char = c.stresc .. "\\n" .. c.base
         codes[i] = char
         char_disp =  2
      end
      -- Reserve one space for ellipsis unless this is the
      -- last character on the line
      local reserved_space = i < #codes and 1 or 0
      if disp + char_disp + reserved_space > max_disp then
         char = c.alert("…")
         codes[i] = char
         disp = disp + 1
         stop_at = i
         break
      end
      disp = disp + char_disp
      if frag_index <= #frag and char == frag:sub(frag_index, frag_index) then
         local char_color
         -- highlight the last two differently if this is a
         -- 'second best' search
         if not best and #frag - frag_index < 2 then
            char_color = c.alert
         else
            char_color = c.search_hl
         end
         char = char_color .. char .. c.base
         codes[i] = char
         frag_index = frag_index + 1
      end
   end
   return c.base(concat(codes, "", 1, stop_at)), disp
end

local function _collect_repr(collection, phrase, c)
   assert(c, "must provide a color table")
   local i = 1
   local first = true
   return function()
      if #collection == 0 then
         if first then
            first = false
            return c.alert "No results found"
         else
            return nil
         end
      end
      local line = collection[i]
      if line == nil then return nil end
      local alt_seq = "    "
      if i < 10 then
         alt_seq = c.bold("M-" .. tostring(i) .. " ")
      end
      line, len = _highlight(line, collection.frag, collection.best, phrase:remains() - 4, c)
      line = alt_seq .. line
      len = len + 4
      if i == collection.hl then
         line = c.highlight(line)
      end
      i = i + 1
      return line, len
   end
end

local collect_M = {__repr = _collect_repr}
collect_M.__index = collect_M


























function Historian.search(historian, frag)
   if historian.last_collection
      and historian.last_collection[1].lit_frag == frag then
      -- don't repeat a search
      return historian.last_collection
   end
   local matches = {}
   local lit_frag = frag
   if frag == "" then
      return Rainbuf {[1] = matches, n = 1}, false
   end
   local slip = nil
   local cursors = {}
   local best = true
   local patt = fuzz_patt(frag)
   for i = historian.n, 1, -1 do
      local score = match(patt, tostring(historian[i]))
      if score then
         matches[#matches + 1] = tostring(historian[i])
         cursors[#cursors + 1] = i
      end
   end
   if #matches == 0 then
      -- try the transpose
      best = false
      slip = frag:sub(1, -3) .. frag:sub(-1, -1) .. frag:sub(-2, -2)
      patt = fuzz_patt(slip)
      for i = historian.n, 1, -1 do
         local score = match(patt, tostring(historian[i]))
         if score then
            matches[#matches + 1] = tostring(historian[i])
            cursors[#cursors + 1] = i
         end
      end
   end
   -- deduplicate
   local collection = setmeta({}, collect_M)
   local collect_cursors = {}
   local dup = {}
   for i, line in ipairs(matches) do
      if not dup[line] then
         dup[line] = true
         collection[#collection + 1] = line
         collect_cursors[#collect_cursors + 1] = cursors[i]
      end
   end

   collection.frag = slip or frag
   collection.lit_frag = lit_frag
   collection.best = best
   collection.cursors = collect_cursors
   collection.hl = 1
   historian.last_collection = Rainbuf {[1] = collection, n = 1, live = true}
   historian.last_collection.made_in = "historian.search"
   return historian.last_collection, best
end








local lines = assert(string.lines)
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
         setmeta(results[i], _db_result_M)
      end
   end
   historian.get_results:reset()
   -- may as well memoize the database call, while we're here
   historian.result_buffer[line_id] = results
   return results
end






local bound = assert(math.bound)

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









local inbounds = assert(math.inbounds)

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

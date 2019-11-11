















local L       = require "lpeg"
local uv      = require "luv"
local sql     = assert(sql, "sql must be in bridge _G")

local Txtbuf  = require "helm/txtbuf"
local Rainbuf = require "helm/rainbuf"
local c       = (require "singletons/color").color
local repr    = require "helm/repr"

local format, sub, codepoints = assert(string.format),
                                assert(string.sub),
                                assert(string.codepoints)
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
INSERT INTO project (directory) VALUES (:dir);
]]

local get_tables = [[
SELECT name FROM sqlite_master WHERE type='table';
]]

local get_recent = [[
SELECT CAST (line_id AS REAL), line FROM repl
   WHERE project = %d
   ORDER BY time
   DESC LIMIT %d;
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

local home_dir = io.popen("echo $HOME", "r"):read("*a"):sub(1, -2)

local bridge_home = io.popen("echo $BRIDGE_HOME", "r"):read("*a"):sub(1, -2)
Historian.bridge_home = bridge_home ~= "" and bridge_home
                        or home_dir .. "/.bridge"

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
   local conn = sql.open(historian.bridge_home)
   historian.conn = conn
   -- Set up bridge tables
   conn.pragma.foreign_keys(true)
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
      ins_proj_stmt : bindkv { dir = historian.project }
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
   local pop_str = sql.format(get_recent, project_id,
                        historian.HISTORY_LIMIT)
   local repl_val  = sql.pexec(conn, pop_str, "i")
   if repl_val then
      local lines = reverse(repl_val[2])
      local line_ids = reverse(repl_val[1])
      historian.line_ids = line_ids
      local repl_map = {}
      for i, v in ipairs(lines) do
         local buf = Txtbuf(v)
         historian[i] = buf
         repl_map[line_ids[i]] = buf
      end
      historian.cursor = #historian
   else
      historian.results = {}
      historian.line_ids = {}
      historian.cursor = 0
   end
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
   frag = type(frag) == "string" and codepoints(frag) or frag
   local patt =  (P(1) - P(frag[1]))^0
   for i = 1 , #frag - 1 do
      local v = frag[i]
      patt = patt * (P(v) * (P(1) - P(frag[i + 1]))^0)
   end
   patt = patt * P(frag[#frag])
   return patt
end













local concat, litpat = assert(table.concat), assert(string.litpat)
local gsub = assert(string.gsub)
local function _highlight(line, frag, best, c)
   local hl = {}
   while #frag > 0 do
      local char
      char, frag = frag:sub(1,1), frag:sub(2)
      local at = line:find(litpat(char))
      if not at then
         break
      end
      local Color
      -- highlight the last two differently if this is a 'second best'
      -- search
      if not best and #frag <= 1 then
         Color = c.alert
      else
         Color = c.search_hl
      end
      hl[#hl + 1] = c.base(line:sub(1, at -1))
      hl[#hl + 1] = Color(char)
      line = line:sub(at + 1)
   end
   hl[#hl + 1] = c.base(line)
   return concat(hl):gsub("\n", c.stresc("\\n"))
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
      local len = #line
      local alt_seq = "    "
      if i < 10 then
         alt_seq = c.bold("M-" .. tostring(i) .. " ")
      end
      len = len + 4
      if len > phrase:remains() then
         line = line:sub(1, phrase:remains() - 5) .. c.alert "…"
         len = phrase.width - (phrase.width - phrase:remains() - 4)
      end
      local next_line = alt_seq
                     .. _highlight(line, collection.frag, collection.best, c)
      if i == collection.hl then
         next_line = c.highlight(next_line)
      end
      i = i + 1
      return next_line, len
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
   local collection = setmeta({}, collect_M)
   collection.frag = frag
   collection.lit_frag = frag
   if frag == "" then
      return Rainbuf {[1] = collection, n = 1}, false
   end
   local cursors = {}
   local best = true
   local patt = fuzz_patt(frag)
   for i = #historian, 1, -1 do
      local score = match(patt, tostring(historian[i]))
      if score then
         collection[#collection + 1] = tostring(historian[i])
         cursors[#cursors + 1] = i
      end
   end
   if #collection == 0 then
      -- try the transpose
      best = false
      local slip = sub(frag, 1, -3) .. sub(frag, -1, -1) .. sub(frag, -2, -2)
      collection.frag = slip
      patt = fuzz_patt(slip)
      for i = #historian, 1, -1 do
         local score = match(patt, tostring(historian[i]))
         if score then
            collection[#collection + 1] = tostring(historian[i])
            cursors[#cursors + 1] = i
         end
      end
   end
   collection.best = best
   collection.cursors = cursors
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
   historian.get_results:clearbind():reset()
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
   historian.cursor = bound(historian.cursor + 1, nil, #historian + 1)
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
   assert(inbounds(cursor, 1, #historian))
   local txtbuf = historian[cursor]:clone()
   txtbuf:endOfText()
   local result = _resultsFrom(historian, cursor)
   historian.cursor = cursor
   return txtbuf, result
end









function Historian.append(historian, txtbuf, results, success)
   if tostring(historian[#historian]) == tostring(txtbuf)
      or tostring(txtbuf) == "" then
      -- don't bother
      return false
   end
   historian[#historian + 1] = txtbuf
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
   historian:load()
   historian.result_buffer = setmetatable({}, __result_buffer_M)
   return historian
end
Historian.idEst = new



return new

















local Txtbuf = require "txtbuf"
local sql     = require "sqlayer"
local color   = require "color"
local L       = require "lpeg"
local format  = assert (string.format)
local sub     = assert (string.sub)
local reverse = assert (table.reverse)
assert(meta)



local Historian = meta {}










Historian.HISTORY_LIMIT = 2000

local create_project_table = [[
CREATE TABLE IF NOT EXISTS project (
project_id INTEGER PRIMARY KEY AUTOINCREMENT,
directory TEXT UNIQUE,
time DATETIME DEFAULT CURRENT_TIMESTAMP );
]]

local create_repl_table = [[
CREATE TABLE IF NOT EXISTS repl (
line_id INTEGER PRIMARY KEY AUTOINCREMENT,
project INTEGER,
line TEXT,
time DATETIME DEFAULT CURRENT_TIMESTAMP,
FOREIGN KEY (project)
   REFERENCES project (project_id)
   ON DELETE CASCADE );
]]

local create_result_table = [[
CREATE TABLE IF NOT EXISTS result (
result_id INTEGER PRIMARY KEY AUTOINCREMENT,
line_id INTEGER,
repr text NOT NULL,
value blob,
FOREIGN KEY (line_id)
   REFERENCES repl (line_id)
   ON DELETE CASCADE );
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

local get_reprs = [[
SELECT CAST (repl.line_id AS REAL), result.repr
FROM repl
LEFT OUTER JOIN result
ON repl.line_id = result.line_id
WHERE repl.project = %d
ORDER BY result.result_id
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
      ins_proj_stmt:bindkv {dir = historian.project}
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
   -- Retrieve history
   local pop_str = sql.format(get_recent, project_id,
                        historian.HISTORY_LIMIT)
   local repl_val, repl_row = sql.pexec(conn, pop_str, "i")
   local res_str = sql.format(get_reprs, project_id,
                       historian.HISTORY_LIMIT * 2)
   local res_val, res_row = sql.pexec(conn, res_str, "i")
   if repl_val and res_val then
      local lines = reverse(repl_val[2])
      local line_ids = reverse(repl_val[1])
      local repl_map = {}
      for i, v in ipairs(lines) do
         local buf = Txtbuf(v)
         historian[i] = buf
         repl_map[line_ids[i]] = buf
      end
      historian.cursor = #historian
      -- reuse line_id var for foreign keys
      line_ids = res_val[1]
      local reprs = res_val[2]
      -- This is keyed by txtbuf with a string value.
      local result_map = {}
      for i = 1, #reprs do
         local buf = repl_map[line_ids[i]]
         if buf then
            local result = result_map[buf] or {frozen = true}
            result[#result + 1] = reprs[i]
            result.n = #result -- for compat with nil in live use
            result_map[buf] = result
         end
      end
      historian.results = result_map
   else
      historian.results = {}
      historian.cursor = 0
   end
end






























function Historian.persist(historian, txtbuf, results)
   local lb = tostring(txtbuf)
   if lb ~= "" then
      historian.insert_line:bindkv { project = historian.project_id,
                                          line    = lb }
      local err = historian.insert_line:step()
      if not err then
         historian.insert_line:clearbind():reset()
      else
         error(err)
      end
      local line_id = sql.lastRowId(historian.conn)
      if results and type(results) == "table" then
         for _,v in ipairs(reverse(results)) do
            -- insert result repr
            historian.insert_result:bindkv { line_id = line_id,
                                                  repr = color.ts(v) }
            err = historian.insert_result:step()
            if not err then
               historian.insert_result:clearbind():reset()
            end
         end
      end

   return true
   else
      -- A blank line can have no results and is uninteresting.
      return false
   end
   --]]
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

local function _highlight(line, frag, c, best)
   local hl = {}
   local og_line = line -- debugging
   while #frag > 0 do
      local char
      char, frag = frag:sub(1,1), frag:sub(2)
      local at = line:find(litpat(char))
      if not at then
         error ("can't find " .. char .. " in: " .. line)
      end
      local color
      -- highlight the last two differently if this is a 'second best'
      -- search
      if not best and #frag <= 1 then
         color = c.alert
      else
         color = c.search_hl
      end
      hl[#hl + 1] = c.base(line:sub(1, at -1))
      hl[#hl + 1] = color(char)
      line = line:sub(at + 1)
   end
   hl[#hl + 1] = c.base(line)
   return concat(hl):gsub("\n", c.stresc("\\n"))
end

local function _collect_repr(collection, c)
   if #collection == 0 then
      return c.alert "No results found"
   end
   local phrase = ""
   for i,v in ipairs(collection) do
      phrase = phrase
               .. _highlight(v, collection.frag, c, collection.best)
               .. "\n"
   end
   return phrase
end

local collect_M = {__repr = _collect_repr}






















function Historian.search(historian, frag)
   local collection = setmeta({}, collect_M)
   collection.frag = frag
   if frag == "" then
      return collection, false
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
   return collection, best
end






function Historian.prev(historian)
   if historian.cursor == 0 or #historian == 0 then
      return Txtbuf()
   end
   local Δ = historian.cursor > 1 and 1 or 0
   local txtbuf = historian[historian.cursor - Δ]
   txtbuf.cur_row = 1
   local result = historian.results[txtbuf]
   historian.cursor = historian.cursor - Δ
   txtbuf.cursor = #txtbuf.lines[txtbuf.cur_row] + 1
   return txtbuf:clone(), result
end











function Historian.next(historian)
   local Δ = historian.cursor < #historian and 1 or 0
   if historian.cursor == 0 or #historian == 0 then
      return Txtbuf()
   end
   local txtbuf = historian[historian.cursor + Δ]
   if not txtbuf then
      return Txtbuf()
   end
   txtbuf.cur_row = #txtbuf.lines
   local result = historian.results[txtbuf]
   if not txtbuf then
      return Txtbuf()
   end
   historian.cursor = historian.cursor + Δ
   txtbuf.cursor = #txtbuf.lines[txtbuf.cur_row] + 1
   if not (Δ > 0) and #txtbuf.lines > 0 then
      historian.cursor = #historian + 1
      return txtbuf:clone(), nil, true
   else
      return txtbuf:clone(), result, false
   end
end








function Historian.index(historian, cursor)
   if cursor < 0 or cursor > #historian + 1 then
      return false
   end
   local txtbuf = historian[cursor]
   local result = historian.results[txtbuf]
   txtbuf = txtbuf:clone()
   historian.cursor = cursor
   txtbuf.cur_row = #txtbuf.lines
   txtbuf.cursor = #txtbuf.lines[txtbuf.cur_row] + 1
   return txtbuf, result
end









function Historian.append(historian, txtbuf, results, success)
   if tostring(historian[#historian]) == tostring(txtbuf) then
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



local function new()
   local historian = meta(Historian)
   historian:load()
   return historian
end
Historian.idEst = new



return new

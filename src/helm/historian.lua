

















local uv      = require "luv"
local sql     = assert(sql, "sql must be in bridge _G")

local Txtbuf  = require "helm/txtbuf"
local Rainbuf = require "helm/rainbuf"
local C       = require "singletons/color"
local repr    = require "helm/repr"
local persist_tabulate = require "helm:helm/repr/persist-tabulate"
local helm_db = require "helm:helm/helm-db"

local concat, insert = assert(table.concat), assert(table.insert)
local reverse = require "core/table" . reverse
local meta = require "core/meta" . meta

local Set = require "set:set"









local Historian = meta {}
Historian.HISTORY_LIMIT = 2000
Historian.helm_db_home = _Bridge.bridge_home .. "/helm/helm.sqlite"
Historian.project = uv.cwd()











local insert_line = [[
INSERT INTO repl (project, line) VALUES (:project, :line);
]]

local insert_result = [[
INSERT INTO result (line_id, repr) VALUES (:line_id, :repr);
]]

local insert_project = [[
INSERT INTO project (directory) VALUES (?);
]]

local insert_session = [[
INSERT INTO session (title, project) VALUES (?, ?);
]]




local get_recent = [[
SELECT CAST (line_id AS REAL), line FROM repl
   WHERE project = :project
   ORDER BY line_id DESC
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


local function has(table, name)
   for _,v in ipairs(table) do
      if name == v then
         return true
      end
   end
   return false
end














local bound, inbounds = import("core:core/math", "bound", "inbounds")
local assertfmt = import("core:core/string", "assertfmt")
local format = assert(string.format)
local boot = assert(helm_db.boot)

function Historian.load(historian)
   local conn = sql.open(historian.helm_db_home, "rwc")
   historian.conn = conn
   -- if necessary, create or migrate the database
   boot(conn)
   -- Retrieve project id
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
   historian.cursor_start = number_of_lines + 1
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
      -- Results are loaded backwards because that's how they're accessed
      counter = counter - 1
   end
   -- add one line to ensure we have history on startup
   load_one()
   -- idle to populate the rest of the history
   idler = uv.new_idle()
   idler:start(load_one)
end











function Historian.beginMacroSession(historian, session_title)
   -- this is incremented for each stored line
   historian.premise_ordinal = 1
   -- insert session into DB
   historian.conn
      : prepare(insert_session)
      : bind(session_title, historian.project_id)
      : step()
   -- retrieve session id
   historian.session_id = sql.lastRowId(historian.conn)
end
















local function ninsert(tab, val)
   tab.n = tab.n + 1
   tab[tab.n] = val
end

local SOH, STX = "\x01", "\x02"

local function dump_token(token, stream)
   ninsert(stream, SOH)
   if token.event then
      ninsert(stream, "event=")
      ninsert(stream, token.event)
   end
   if token.wrappable then
      if token.event then ninsert(stream, " ") end
      ninsert(stream, "wrappable")
   end
   ninsert(stream, STX)
   ninsert(stream, tostring(token))
   return stream
end

local tabulate = require "helm/repr/tabulate"
local tab_callback = assert(persist_tabulate.tab_callback)

function Historian.persist(historian, txtbuf, results)
   local lb = tostring(txtbuf)
   local have_results = results
                        and type(results) == "table"
                        and results.n
   if lb == "" then
      -- A blank line can have no results and is uninteresting.
      return false
   end
   historian.conn:exec("SAVEPOINT save_persist")
   historian.insert_line:bindkv { project = historian.project_id,
                                       line    = sql.blob(lb) }
   local err = historian.insert_line:step()
   if not err then
      historian.insert_line:clearbind():reset()
   else
      error(err)
   end
   local line_id = sql.lastRowId(historian.conn)
   insert(historian.line_ids, line_id)

   -- If there's nothing to persist, release our savepoint
   -- and don't bother starting the idler
   if not have_results then
      historian.conn:exec("RELEASE save_persist")
      return true
   end

   local results_tostring, results_tabulates = {}, {}
   -- Make a dummy table to stand in for Composer:window(),
   -- since we won't be making a Composer at all.
   local dummy_window = { width = 80, remains = 80, color = C.no_color }
   for i = 1, results.n do
      results_tabulates[i] = tabulate(results[i], dummy_window, C.no_color)
      results_tostring[i] = { n = 0 }
   end
   local persist_cb = tab_callback(results_tabulates, results_tostring)
   local persist_idler = uv.new_idle()
   historian.idlers:insert(persist_idler)
   persist_idler:start(function()
      local done, results_tostring = persist_cb()
      if not done then return nil end
      -- now persist
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
      historian.conn:exec("RELEASE save_persist")
      persist_idler:stop()
      assert(historian.idlers:remove(persist_idler) == true)
   end)
   return true
end






























local SelectionList = require "helm/selection_list"
local fuzz_patt = require "helm:helm/fuzz_patt"

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
         if not dup[item_str] and patt:match(item_str) then
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
local find, match, sub = assert(string.find),
                         assert(string.match),
                         assert(string.sub)
local Token = require "helm/repr/token"
local function _db_result__repr(result)
   if sub(result[1], 1, 1) == SOH then
      -- New format--tokens delimited by SOH/STX
      local header_position = 1
      local text_position = 0
      return function()
         text_position = find(result[1], STX, header_position + 1)
         if not text_position then
            return nil
         end
         local metadata = sub(result[1], header_position + 1, text_position - 1)
         local cfg = {}
         if find(metadata, "wrappable") then cfg.wrappable = true end
         cfg.event = match(metadata, "event=(%w+)")
         header_position = find(result[1], SOH, text_position + 1)
         if not header_position then
            header_position = #result[1] + 1
         end
         local text = sub(result[1], text_position + 1, header_position - 1)
         return Token(text, C.color.greyscale, cfg)
      end
   else
      -- Old format--just a string, which we'll break up into lines
      local line_iter = lines(result[1])
      return function()
         local line = line_iter()
         if line then
            -- Might as well return a Token in order to attach the color properly,
            -- rather than just including the color escapes in the string
            return Token(line, C.color.greyscale, { event = "repr_line" })
         else
            return nil
         end
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
   local results = stmt :resultset 'i'
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
function __result_buffer_M.__repr(buf, window, c)
   return c.alert "cowardly refusing to print result_buffer to avoid infinite appending"
end

local function new(helm_db)
   local historian = meta(Historian)
   if helm_db then
      historian.helm_db_home = helm_db
   end
   historian.line_ids = {}
   historian.cursor = 0
   historian.cursor_start = 0
   historian.n = 0
   historian:load()
   historian.result_buffer = setmetatable({}, __result_buffer_M)
   historian.idlers = Set()
   return historian
end
Historian.idEst = new



return new

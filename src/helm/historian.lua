














local uv      = require "luv"
local sql     = assert(sql, "sql must be in bridge _G")

local Txtbuf  = require "helm:txtbuf"
local Resbuf  = require "helm:resbuf"
local Session = require "helm:session"
local C       = require "singletons:color"
local persist_tabulate = require "repr:persist-tabulate"
local helm_db = require "helm:helm-db"

local concat, insert = assert(table.concat), assert(table.insert)
local reverse = require "core/table" . reverse
local meta = require "core/meta" . meta
local sha = assert(require "util:sha" . shorthash)

local Set = require "set:set"






local Historian = meta {}
Historian.HISTORY_LIMIT = 2000
Historian.helm_db_home = helm_db.helm_db_home
Historian.project = uv.cwd()





function Historian.createPreparedStatements(historian, helm_db_home)
   if helm_db_home then
      historian.helm_db_home = helm_db_home
   end
   local stmts = helm_db.historian(historian.helm_db_home)
   historian.stmts = stmts
   historian.insert_line = stmts.insert_line
   historian.insert_repr = stmts.insert_repr
   historian.insert_result_hash = stmts.insert_result_hash
   historian.get_results = stmts.get_results
end















local clamp, inbounds = import("core:core/math", "clamp", "inbounds")
local assertfmt = import("core:core/string", "assertfmt")
local format = assert(string.format)

function Historian.load(historian)
   local stmts = historian.stmts
   -- Retrieve project id
   local proj_val, proj_row = stmts.get_project
                                      : bind(historian.project)
                                      : resultset 'i'
   if not proj_val then
      proj_val, proj_row = stmts.insert_project
                             : bind(historian.project)
                             : step()
      -- retry
      proj_val, proj_row = stmts.get_project
                                      : bind(historian.project)
                                      : resultset 'i'
      if not proj_val then
         error "Could not create project in .bridge"
      end
   end
   local project_id = proj_val[1][1]
   historian.project_id = project_id
   -- Retrieve history
   local number_of_lines = stmts.get_number_of_lines
                             :bind(project_id):step()[1]
   if number_of_lines == 0 then
      return nil
   end
   number_of_lines = clamp(number_of_lines, nil, historian.HISTORY_LIMIT)
   local pop_stmt = stmts.get_recent
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








local tabulate = require "repr:tabulate"
local tab_callback = assert(persist_tabulate.tab_callback)

function Historian.persist(historian, txtbuf, results)
   local lb = tostring(txtbuf)
   if type(results) ~= "table" or results.n == 0 then
      results = nil
   end
   if lb == "" then
      -- A blank line can have no results and is uninteresting.
      return false
   end
   historian.stmts.savepoint_persist()
   historian.insert_line:bindkv { project = historian.project_id,
                                       line    = sql.blob(lb) }
   local err = historian.insert_line:step()
   if not err then
      historian.insert_line:clearbind():reset()
   else
      error(err)
   end
   local line_id = historian.stmts.lastRowId()
   insert(historian.line_ids, line_id)
   -- If there's nothing to persist, release our savepoint
   -- and don't bother starting the idler
   if not results then
      historian.stmts.release_persist()
      return line_id
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
         local hash = sha(results_tostring[i])
         historian.insert_result_hash:bind(line_id, hash)
         err = historian.insert_result_hash:step()
         if not err then
            historian.insert_result_hash :clearbind() :reset()
         else
            error(err)
         end
         historian.insert_repr:bind(hash, results_tostring[i])
         err = historian.insert_repr:step()
         if not err then
            historian.insert_repr :clearbind() :reset()
         else
            error(err)
         end
      end
      historian.stmts.release_persist()
      persist_idler:stop()
      assert(historian.idlers:remove(persist_idler) == true)
   end)
   return line_id
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
   historian.last_collection = Resbuf({ result, n = 1 }, { live = true })
   historian.last_collection.made_in = "historian.search"
   return historian.last_collection
end



local db_result_M = assert(persist_tabulate.db_result_M)

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
         setmetatable(results[i], db_result_M)
      end
   end
   stmt:reset()
   -- may as well memoize the database call, while we're here
   historian.result_buffer[line_id] = results
   return results
end






function Historian.prev(historian)
   historian.cursor = clamp(historian.cursor - 1, 1)
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
   historian.cursor = clamp(historian.cursor + 1, nil, historian.n + 1)
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
   historian.n = historian.n + 1
   historian[historian.n] = txtbuf
   if not success then results = nil end
   historian.result_buffer[historian.n] = results
   local line_id = historian:persist(txtbuf, results)
   historian.session:append(line_id, txtbuf, results)
   return true
end
















local __result_buffer_M = meta {}
function __result_buffer_M.__repr(buf, window, c)
   return c.alert "cowardly refusing to print result_buffer to avoid infinite appending"
end

local function new(helm_db)
   local historian = meta(Historian)
   historian.line_ids = {}
   historian.cursor = 0
   historian.cursor_start = 0
   historian.n = 0
   historian:createPreparedStatements(helm_db)
   historian:load()
   historian.session = Session(helm_db, { project_id = historian.project_id })
   -- retrieve data from _Bridge
   if _Bridge.args.helm then
      if _Bridge.args.macro then
         historian.session.session_title = _Bridge.args.macro
         historian.session.accepted = true
         historian.session.mode = "macro"
      elseif _Bridge.args.new_session then
         historian.session.session_title = _Bridge.args.new_session
         -- #todo initiate record-then-review mode
      elseif _Bridge.args.session then
         historian.session.session_title = _Bridge.args.session
         historian.session:load()
      end
   end
   historian.result_buffer = setmetatable({}, __result_buffer_M)
   historian.idlers = Set()
   return historian
end

Historian.idEst = new



return new


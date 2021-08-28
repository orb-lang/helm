









local uv  = require "luv"
local sql = assert(sql, "sql must be in bridge _G")






local helm_db = {}






local helm_db_home =  os.getenv 'HELM_HOME'
                      or _Bridge.bridge_home .. "/helm/helm.sqlite"
helm_db.helm_db_home = helm_db_home











local _conns = setmetatable({}, { __mode = 'v' })











local function _resolveConn(conn)
   if conn then
      if type(conn) == 'string' then
         return _conns[conn]
      else
         return conn
      end
   end
   return nil
end









local function _openConn(conn_handle)
   if not conn_handle then
      conn_handle = helm_db_home
   end
   local conn = _resolveConn(conn_handle)
   if not conn then
      conn = helm_db.boot(conn_handle)
   end
   assert(conn, "no conn! " .. conn_handle)
   return conn
end





























































































































































helm_db.HELM_DB_VERSION = 3

local migrations = {function() return true end}
helm_db.migrations = migrations






local insert = assert(table.insert)

local migration_2 = {
   create_project_table,
   create_result_table,
   create_repl_table,
   create_session_table
}

insert(migrations, migration_2)













local migration_3 = {}








migration_3[2] = create_project_table_3























migration_3[7] = create_repl_table_3


















insert(migrations, migration_3)



























local migration_4 = {}







insert(migration_4, create_session_table_4)
insert(migration_4, create_premise_table)

insert(migrations, migration_4)








local migration_5 = {}
insert(migrations, migration_5)














































migration_5[3] = create_session_table_5







































































































migration_5[7] = create_result_table_5
migration_5[8] = create_repr_table
migration_5[9] = create_repr_hash_idx













































local TRUNCATE_AT = 1048576 * 4 -- 4 MiB is long enough for one repr...

local function _truncate_repr(repr)
   local idx = TRUNCATE_AT
   if repr:sub(1, 1) == "\x01" then
      -- If this is a tokenized-format repr, look for the start of
      -- the next token after the 4MB mark, and stop just before it.
      -- Theoretically there might not be any such, if the repr is just
      -- barely over 4MB, in which case we keep the whole thing.
      idx = repr:find("\x01", idx, true)
      if idx then
         idx = idx - 1
      end
   end
   return repr:sub(1, idx)
end

migration_5[10] = function (conn, s)
   local sha = require "util:sha" . shorthash
   local insert_result = conn:prepare(insert_new_result_5)
   local insert_repr = conn:prepare(insert_repr_5)
   s:chat "Hashing results, this may take awhile..."
   local truncated = 0
   for _, result_id, line_id, repr in conn:prepare(get_old_result_5):cols() do
      ---[[
      if #repr > TRUNCATE_AT then
         s:verb("Found a %.2f MiB result!", #repr / 1048576)
         truncated = truncated + 1
         repr = _truncate_repr(repr)
      end
      --]]
      local hash = sha(repr)
      insert_result :bind(result_id, line_id, hash)
                    :step()
      insert_result :clearbind() :reset()
      insert_repr :bind(hash, repr) :step()
      insert_repr :clearbind() :reset()
   end
   s:chat("Truncated %d results", truncated)
   s:verb(drop_result_5)
   s:verb(rename_result_5)
   conn:exec(drop_result_5)
   conn:exec(rename_result_5)
   return true
end

















local migration_6 = {}

insert(migrations, migration_6)

































































































































































insert(migration_6, create_run_table)
insert(migration_6, create_run_attr_table)
insert(migration_6, create_run_action_table)
insert(migration_6, create_action_attr_table)
insert(migration_6, create_error_string_table)
insert(migration_6, create_error_string_idx)










































local function _prepareStatements(conn, stmts)
   return function(_, key)
      if stmts[key] then
         return conn:prepare(stmts[key])
      else
         error("Don't have a statement " .. key .. " to prepare.")
      end
   end
end

local function _readOnly(_, key, value)
   error ("can't assign to prepared statements table, key: " .. key
          .. " value: " .. value)
end

local lastRowId = assert(sql.lastRowId)
function _makeProxy(conn, stmts)
   return setmetatable({ lastRowId = function() return lastRowId(conn) end },
                       { __index = _prepareStatements(conn, stmts),
                         __newindex = _readOnly })
end












local historian_sql = {}
helm_db.historian_sql = historian_sql

























































function helm_db.historian(conn_handle)
   local conn = _openConn(conn_handle)
   local hist_proxy = _makeProxy(conn, historian_sql)
   rawset(hist_proxy, "savepoint_persist",
          function()
            conn:exec "SAVEPOINT save_persist"
          end)
   rawset(hist_proxy, "release_persist",
          function()
             conn:exec "RELEASE save_persist"
          end)
   rawset(hist_proxy, "savepoint_restart_session",
          function()
             conn:exec "SAVEPOINT restart_session"
          end)
   rawset(hist_proxy, "release_restart_session",
          function()
             conn:exec "RELEASE restart_session"
          end)
   return hist_proxy
end









local session_sql = {}









































session_sql.insert_result_hash = historian_sql.insert_result_hash
session_sql.insert_repr        = historian_sql.insert_repr














































































































































































function helm_db.session(conn_handle)
   local conn = _openConn(conn_handle)
   local stmts =  _makeProxy(conn, session_sql)
   rawset(stmts, "get_project_info",
          function()
             return conn:exec(session_get_project_info)
          end)
   rawset(stmts, "beginTransaction",
          function()
             return conn:exec "BEGIN TRANSACTION;"
          end)
   rawset(stmts, "commit",
          function()
             return conn:exec "COMMIT;"
          end)
   return stmts
end











local assertfmt = require "core:core/string" . assertfmt
local format = assert(string.format)
local boot = assert(sql.boot)


function helm_db.boot(conn_handle)
   local conn = _resolveConn(conn_handle)
   if not conn then
      conn_handle = helm_db_home
      conn = boot(conn_handle, migrations)
      _conns[conn_handle] = conn
   end

   return conn
end








function helm_db.close(conn_handle)
   local conn = _resolveConn(conn_handle)
   if not conn then
      conn = _conns[helm_db_home]
      conn_handle = helm_db_home
   end
   if not conn then return end
   pcall(conn.pragma.wal_checkpoint, "0") -- 0 == SQLITE_CHECKPOINT_PASSIVE
   -- set up an idler to close the conn, so that e.g. busy
   -- exceptions don't blow up the hook
   local close_idler = uv.new_idle()
   close_idler:start(function()
      local success = pcall(conn.close, conn)
      if not success then
         return nil
      else
         -- we don't want to rely on GC to prevent closing a conn twice
         _conns[conn_handle] = nil
         close_idler:stop()
      end
   end)
end










function helm_db.conn(conn_handle)
   conn_handle = conn_handle or helm_db_home
   return _conns[conn_handle]
end








setmetatable(helm_db, { __newindex = function()
                                        error "cannnot assign to helm_db"
                                     end })




return helm_db

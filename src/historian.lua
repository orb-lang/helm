















local Linebuf = require "linebuf"
local sql = require "sqlayer"



local Historian = meta {}








local cl = assert(table.clone, "table.clone must be provided")

local function clone(linebuf)
   local lb = cl(linebuf)
   lb.line = cl(lb.line)
   return lb
end









Historian.HISTORY_LIMIT = 50

local create_repl_table = [[
CREATE TABLE repl (
line_id INTEGER PRIMARY KEY AUTOINCREMENT,
project TEXT,
line TEXT,
time DATETIME DEFAULT CURRENT_TIMESTAMP);
]]

local insert_line_stmt = [[
INSERT INTO repl (project, line) VALUES(?, ?);
]]

local get_tables = [[
SELECT name FROM sqlite_master WHERE type='table';
]]

local get_recent = [[
SELECT line FROM repl
   WHERE project = ?
   ORDER BY time
   DESC LIMIT ?;
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

function Historian.load(historian)
   local conn = sql.open(historian.home_dir .. "/.bridge")
   historian.conn = conn
   local table_names = conn:exec(get_tables)
   if not table_names or not has(table_names, "repl") then
      local success, err = sql.pexec(conn, create_repl_table)
      -- success is nil for creation, false for error
      if success == false then
         error(err)
      end
   end
   historian.insert_stmt = conn:prepare(insert_line_stmt)
   local pop_stmt = conn:prepare(get_recent)
   historian.pop_stmt = pop_stmt -- remove
   pop_stmt:bind(historian.project, historian.HISTORY_LIMIT)
   local values, err = pop_stmt:step()
   if values then
      historian.values = values
      return values
   else

      if values then
         return values
      else
         return false, err
      end
   end
end

function Historian.persist(historian, linebuf)
   local lb = tostring(linebuf)
   historian.insert_stmt:bind(historian.project, lb)
   local err = historian.insert_stmt:step()
   if not err then
      historian.insert_stmt:clearbind():reset()
   else
      error(error)
   end
   return true
end





function Historian.prev(historian)
   if historian.cursor == 0 then
      return Linebuf(1)
   end
   local minus = historian.cursor > 1 and 1 or 0
   local linebuf
   if historian.cursor == #historian then
      linebuf = clone(historian[#historian])
   else
      linebuf = clone(historian[historian.cursor])
   end
   historian.cursor = historian.cursor - minus
   linebuf.cursor = #linebuf.line + 1
   return linebuf
end









function Historian.next(historian)
   local plus = historian.cursor < #historian and 1 or 0
   if historian.cursor == 0 then
      return Linebuf(1)
   end
   historian.cursor = historian.cursor + plus
   local linebuf = clone(historian[historian.cursor])
   linebuf.cursor = #linebuf.line + 1
   if not (plus > 0) and #linebuf.line > 0 then
      return linebuf, true
   else
      return linebuf, false
   end
end






function Historian.append(historian, linebuf)
   historian[#historian + 1] = linebuf
   historian.cursor = #historian
   historian:persist(linebuf)
   return true
end



local function new(linebuf)
   local historian = meta(Historian)
   historian[1] = linebuf
   historian.cursor = linebuf and 1 or 0
   historian:load()
   return historian
end
Historian.idEst = new



return new

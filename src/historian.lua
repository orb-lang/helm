















local Linebuf = require "linebuf"
local sql     = require "sqlayer"
local format  = assert (string.format)



local Historian = meta {}









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




local STATCOL = 81
local STAT_TOP = 1
local STAT_RUN = 2

local function colwrite(str, col, row)
   col = col or STATCOL
   row = row or STAT_TOP
   local dash = a.stash()
             .. a.cursor.hide()
             .. a.jump(row, col)
             .. a.erase.right()
             .. str
             .. a.pop()
             .. a.cursor.show()
   write(dash)
end



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
      return Linebuf()
   end
   local delta = historian.cursor > 1 and 1 or 0
   local linebuf = historian[historian.cursor - delta]:clone()
   historian.cursor = historian.cursor - delta
   linebuf.cursor = #linebuf.line + 1
   return linebuf
end









function Historian.next(historian)
   local delta = historian.cursor < #historian and 1 or 0
   if historian.cursor == 0 then
      return Linebuf()
   end
   local linebuf= historian[historian.cursor + delta]:clone()
   historian.cursor = historian.cursor + delta
   linebuf.cursor = #linebuf.line + 1
   if not (delta > 0) and #linebuf.line > 0 then
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



local function new()
   local historian = meta(Historian)
   historian:load()
   return historian
end
Historian.idEst = new



return new

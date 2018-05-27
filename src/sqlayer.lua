










local sql = require "sqlite"
local pcall = assert (pcall)
local gsub = assert(string.gsub)
local format = assert(string.format)








local function san(str)
   return gsub(str, "'", "''")
end

sql.san = san


























function sql.format(str, ...)
   local argv = {...}
   str = gsub(str, "%%s", "'%%s'"):gsub("''%%s''", "'%%s'")
   for i, v in ipairs(argv) do
      if type(v) == "string" then
         argv[i] = san(v)
      else
         argv[i] = v
      end
   end
   local success, ret = pcall(format, str, unpack(argv))
   if success then
      return ret
   else
      return success, ret
   end
end









function sql.pexec(conn, stmt, col_str)
   -- conn:exec(stmt)
   col_str = col_str or "hik"
   local success, result, nrow = pcall(conn.exec, conn, stmt, col_str)
   if success then
      return result, nrow
   else
      return false, value
   end
end










function sql.lastRowId(conn)
   local result = conn:rowexec "SELECT CAST(last_insert_rowid() AS REAL)"
   return result
end




return sql

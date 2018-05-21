







local sql = require "sqlite"
local pcall = assert (pcall)
local gsub = assert(string.gsub)








function sql.san(str)
   return gsub(str, "'", "''")
end









function sql.pexec(conn, stmt)
   -- conn:exec(stmt)
   local success, value = pcall(conn.exec, conn, stmt)
   if success then
      return value
   else
      return false, value
   end
end



return sql

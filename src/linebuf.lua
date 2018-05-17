































local Linebuf = meta()




local function sum(dsps)
   local summa = 0
   for i = 1, #dsps do
      summa = summa + #dsps[i]
   end
   return summa
end

local concat = table.concat
function Linebuf.__tostring(linebuf)
   assert(linebuf.depth
          and type(linebuf.depth) == "number"
          and linebuf.depth > 0,
          "linebuf.depth must be a positive integer")
   if linebuf.depth == 1 then
      return concat(linebuf)
   else
      error("tostring on linebuf.depth > 1 NYI")
   end
end














function Linebuf.insert(linebuf, frag)

end





local function new(cursor)
   local linebuf = meta(Linebuf)
   linebuf.back  =  false
   -- disps = #str for str in line
   linebuf.dsps = {0}
   linebuf.line  = {""}
   -- Cursor may be nil
   linebuf.cursor = cursor
   return linebuf
end



return new



































local sub = assert(string.sub)



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
   -- return concat(linebuf.line)
   -- patch to see tok boundaries
   local phrase = ""
   for _, tok in ipairs(linebuf.line) do
      phrase = phrase .. tok .. a.red("|")
   end
   return phrase
end














-- a pass through for now
local function join(token, frag)
   if sub(token, -1) == " " and sub(frag, 1,1) ~= " " then
      return token, frag
   else
      return token .. frag, nil
   end
end

function Linebuf.insert(linebuf, frag)
   assert(linebuf.cursor, "linebuf must have cursor to insert")
   local line = linebuf.line
   -- end of line
   if cursor == len then
      local token, new_tok = join(line[#line], frag)
      line[#line] = token
      if new_tok then
         line[#line + 1] = new_tok
      end
      linebuf.len = sum(line)
      linebuf.cursor = linebuf.cursor + #frag
      return true
   end
   return false
end




local function new(cursor)
   local linebuf = meta(Linebuf)
   linebuf.back  =  false
   linebuf.len = 0 -- in bytes
   linebuf.line  = {""}
   -- Cursor may be nil
   linebuf.cursor = cursor
   return linebuf
end



return new

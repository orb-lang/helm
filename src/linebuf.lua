



































local sub, byte = assert(string.sub), assert(string.byte)



local Linebuf = meta {}




local function sum(dsps)
   local summa = 0
   for i = 1, #dsps do
      summa = summa + #dsps[i]
   end
   return summa
end

local concat = table.concat

function Linebuf.__tostring(linebuf)
   return concat(linebuf.line)
end



















local function join(token, frag)
   if sub(token, -1) == " " and sub(frag, 1,1) ~= " " then
      return token, frag
   else
      return token .. frag, nil
   end
end

local t_insert, splice = assert(table.insert), assert(table.splice)
local utf8, codepoints = string.utf8, string.codepoints

function Linebuf.insert(linebuf, frag)
   local line = linebuf.line
   local wide_frag = utf8(frag)
   if wide_frag < #frag then -- a paste
      wide_frag = codepoints(frag)
   else
      wide_frag = false
   end
   if not wide_frag then
      t_insert(line, linebuf.cursor, frag)
      linebuf.cursor = linebuf.cursor + 1
      return true
   else
      splice(line, linebuf.cursor, wide_frag)
      linebuf.cursor = linebuf.cursor + #wide_frag
      return true
   end

   return false
end

local remove = table.remove

function Linebuf.d_back(linebuf)
   remove(linebuf.line, linebuf.cursor - 1)
   linebuf.cursor = linebuf.cursor > 1 and linebuf.cursor - 1 or 1
end


function Linebuf.d_fwd(linebuf)
   remove(linebuf.line, linebuf.cursor)
end

function Linebuf.left(linebuf, disp)
   local disp = disp or 1
   if linebuf.cursor - disp >= 1 then
      linebuf.cursor = linebuf.cursor - disp
      return linebuf.cursor
   else
      linebuf.cursor = 1
      return linebuf.cursor
   end
end

function Linebuf.right(linebuf, disp)
   disp = disp or 1
   if linebuf.cursor + disp <= #linebuf.line + 1 then
      linebuf.cursor = linebuf.cursor + disp
   else
      linebuf.cursor = #linebuf.line + 1
   end
   return linebuf.cursor
end





function Linebuf.suspend(linebuf)
   linebuf.line = tostring(linebuf)
   linebuf.line = nil
   linebuf.cursor = nil
   return linebuf
end

function Linebuf.resume(linebuf)
   linebuf.line = codepoints(linebuf.line)
   linebuf.cursor = #linebuf.line + 1
   return linebuf
end



local cl = assert(table.clone, "table.clone must be provided")

function Linebuf.clone(linebuf)
   local lb = cl(linebuf)
   if type(lb.line) == "table" then
      lb.line = cl(lb.line)
   elseif type(lb.line) == "string" then
      lb:resume()
   end
   return lb
end



local function new(cursor)
   local linebuf = meta(Linebuf)
   linebuf.line  = {}
   -- Cursor may be nil, for multi-line
   linebuf.cursor = cursor
   return linebuf
end



return new































local sub, byte = assert(string.sub), assert(string.byte)
local gsub = assert(string.gsub)
assert(meta, "linebuf requires meta")



local Linebuf = meta {}



local concat = table.concat

function Linebuf.__tostring(linebuf)
   if type(linebuf.lines) == "table" then
      return concat(linebuf.lines)
   else
      return linebuf.lines
   end
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
   local line = linebuf.lines
   if type(line) == "string" then
      line = codepoints(line)
      linebuf.lines = line
   end
   local wide_frag = utf8(frag)
   if wide_frag < #frag then -- a paste
      -- Normalize whitespace
      frag = gsub(frag, "\r\n", "\n"):gsub("\r", "\n"):gsub("\t", "   ")
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
   remove(linebuf.lines, linebuf.cursor - 1)
   linebuf.cursor = linebuf.cursor > 1 and linebuf.cursor - 1 or 1
end


function Linebuf.d_fwd(linebuf)
   remove(linebuf.lines, linebuf.cursor)
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
   if linebuf.cursor + disp <= #linebuf.lines + 1 then
      linebuf.cursor = linebuf.cursor + disp
   else
      linebuf.cursor = #linebuf.lines + 1
   end
   return linebuf.cursor
end





local cl = assert(table.clone, "table.clone must be provided")

function Linebuf.suspend(linebuf)
   linebuf.lines = tostring(linebuf)
   return linebuf
end

function Linebuf.resume(linebuf)
   linebuf.lines = codepoints(linebuf.lines)
   linebuf.cursor = #linebuf.lines + 1
   return linebuf
end



function Linebuf.clone(linebuf)
   local lb = cl(linebuf)
   if type(lb.lines) == "table" then
      lb.lines = cl(lb.lines)
   elseif type(lb.lines) == "string" then
      lb:resume()
   end
   return lb
end



local function new(line)
   local linebuf = meta(Linebuf)
   linebuf.cursor = line and #line or 1
   linebuf.lines  = line or {}
   return linebuf
end



return new




















































assert(meta)
local collect = assert(table.collect)
local lines = assert(string.lines)
local codepoints = assert(string.codepoints)



local Txtbuf = meta {}





local concat = assert(table.concat)

local function cat(l)
   if type(l) == "string" then
      return l
   elseif type(l) == "table" then
      if l[1] ~= nil then
         return concat(l)
      else
         return ""
      end
   end

   error("called private fn cat with type" .. type(l))
end





function Txtbuf.__tostring(txtbuf)
   local phrase = ""
   for i = 1, #txtbuf.lines - 1 do
      phrase = phrase .. cat(txtbuf.lines[i]) .. "\n"
   end

   return phrase .. cat(txtbuf.lines[#txtbuf.lines])
end







local t_insert, splice = assert(table.insert), assert(table.splice)
local utf8, codepoints = string.utf8, string.codepoints

function Txtbuf.insert(txtbuf, frag)
   local line = txtbuf.lines[txtbuf.cur_row]
   if type(line) == "string" then
      line = codepoints(line)
      txtbuf.line = line
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
      t_insert(line, txtbuf.cursor, frag)
      txtbuf.cursor = txtbuf.cursor + 1
      return true
   else
      splice(line, txtbuf.cursor, wide_frag)
      txtbuf.cursor = txtbuf.cursor + #wide_frag
      return true
   end

   return false
end





local ts_bw = (require "color").ts_bw

function Txtbuf.advance(txtbuf)
   txtbuf.lines[#txtbuf.lines + 1] = {}
   txtbuf.cur_row = #txtbuf.lines
   txtbuf.cursor = 1
   log("advanced %s", ts_bw(txtbuf))
end





local remove = assert(table.remove)

function Txtbuf.d_back(txtbuf)
   remove(txtbuf.lines[txtbuf.cur_row], txtbuf.cursor - 1)
   txtbuf.cursor = txtbuf.cursor > 1 and txtbuf.cursor - 1 or 1
end






function Txtbuf.d_fwd(txtbuf)
   remove(txtbuf.lines[txtbuf.cur_row], txtbuf.cursor)
end






function Txtbuf.left(txtbuf, disp)
   local disp = disp or 1
   if txtbuf.cursor - disp >= 1 then
      txtbuf.cursor = txtbuf.cursor - disp
   else
      txtbuf.cursor = 1
   end

   return txtbuf.cursor
end






function Txtbuf.right(txtbuf, disp)
   disp = disp or 1
   local line = txtbuf.lines[txtbuf.cur_row]
   if txtbuf.cursor + disp <= #line + 1 then
      txtbuf.cursor = txtbuf.cursor + disp
   else
      txtbuf.cursor = #line + 1
   end

   return txtbuf.cursor
end




function Txtbuf.suspend(txtbuf)
   for i,v in ipairs(txtbuf.lines) do
      txtbuf.lines[i] = tostring(v)
   end

   return txtbuf
end



function Txtbuf.resume(txtbuf)
   for i, line in ipairs(txtbuf.lines) do
      txtbuf.lines[i] = codepoints(line)
   end
   txtbuf.cursor = #txtbuf.lines[#txtbuf.lines] + 1
   txtbuf.cur_row = #txtbuf.lines

   return txtbuf
end



local cl = assert(table.clone, "table.clone must be provided")

-- #todo rewrite this

function Txtbuf.clone(txtbuf)
   local lb = cl(txtbuf)
   if type(lb.line) == "table" then
      lb.line = cl(lb.line)
   elseif type(lb.line) == "string" then
      lb:resume()
   end
   return lb
end






local function into_codepoints(lines)
   local cp = {}
   for i,v in ipairs(lines) do
      cp[i] = codepoints(v)
   end

   return cp
end

local function new(line)
   local txtbuf = meta(Txtbuf)
   local __l = line or ""
   local _lines = into_codepoints(collect(lines, __l))
   if #_lines == 0 then
      _lines[1] = {}
   end
   txtbuf.cursor = line and #_lines[#_lines] + 1 or 1
   txtbuf.cur_row = line and #_lines  or 1
   txtbuf.lines = _lines
   return txtbuf
end

Txtbuf.idEst = new



return new

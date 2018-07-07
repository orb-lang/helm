


















































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
end









local remove = assert(table.remove)

function Txtbuf.d_back(txtbuf)
   local cursor, cur_row = txtbuf.cursor, txtbuf.cur_row
   if cursor > 1 then
      remove(txtbuf.lines[cur_row], cursor - 1)
      txtbuf.cursor = cursor - 1
      return false
   elseif cur_row == 1 then
      return false
   else
      local new_line = concat(txtbuf.lines[cur_row - 1])
                       .. concat(txtbuf.lines[cur_row])
      local new_cursor = #txtbuf.lines[cur_row - 1]
      txtbuf.lines[cur_row - 1] = codepoints(new_line)
      remove(txtbuf.lines, cur_row)
      txtbuf.cur_row = cur_row - 1
      txtbuf.cursor = new_cursor
      return true
   end
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






function Txtbuf.up(txtbuf)
   local cur_row = txtbuf.cur_row
   if cur_row == 1 then
      return false
   else
      txtbuf.cur_row = cur_row - 1
      if txtbuf.cursor > #txtbuf.lines[txtbuf.cur_row] + 1 then
         txtbuf.cursor = #txtbuf.lines[txtbuf.cur_row] + 1
      end
      return true
   end
end



function Txtbuf.down(txtbuf)
   local cur_row = txtbuf.cur_row
   if cur_row == #txtbuf.lines then
      return false
   else
      txtbuf.cur_row = cur_row + 1
      if txtbuf.cursor > #txtbuf.lines[txtbuf.cur_row] + 1 then
         txtbuf.cursor = #txtbuf.lines[txtbuf.cur_row] + 1
      end
      return true
   end
end







local sub = assert(string.sub)
local insert = assert(table.insert)
function Txtbuf.nl(txtbuf)
   -- Most txtbufs are one line, so we always evaluate from
   -- a one-liner, regardless of cursor location.
   local linum = #txtbuf.lines
   local cursor = txtbuf.cursor
   local cur_row = txtbuf.cur_row
   if linum == 1 then
      return true
   end
   if cur_row == 1 and cursor > #txtbuf.lines[1] then
      return true
   end
   if cur_row == linum and cursor > #txtbuf.lines[linum] then
      return true
   else
      -- split the line
      local cur_line = concat(txtbuf.lines[txtbuf.cur_row])
      local first = sub(cur_line, 1, cursor - 1)
      local second = sub(cur_line, cursor)
      txtbuf.lines[cur_row] = codepoints(first)
      insert(txtbuf.lines, cur_row + 1, codepoints(second))
      txtbuf.cursor = 1
      txtbuf.cur_row = cur_row + 1
      return false
   end
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

function Txtbuf.clone(txtbuf)
   local tb = cl(txtbuf)
   tb.lines = cl(txtbuf.lines)
   if type(tb.lines[1]) == "string" then
      return tb:resume()
   end
   return tb
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

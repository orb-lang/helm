




















































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






function Txtbuf.openRow(txtbuf,row_num)
   local line = txtbuf.lines[row_num]
   if type(line) == "string" then
      txtbuf.lines[row_num] = codepoints(line)
   end
end

function Txtbuf.closeRow(txtbuf,row_num)
   local line = txtbuf.lines[row_num]
   if type(line) == "table" then
      txtbuf.lines[row_num] = concat(line)
   end
end

function Txtbuf.switchRow(txtbuf,new_row)
   if txtbuf.cur_row == new_row then return end
   txtbuf:closeRow(txtbuf.cur_row)
   txtbuf.cur_row = new_row
   txtbuf:openRow(txtbuf.cur_row)
end







local t_insert, splice = assert(table.insert), assert(table.splice)
local utf8, codepoints, gsub = string.utf8, string.codepoints, string.gsub

local _frag_sub = { ["("] = {"(", ")"},
                    ['"'] = {'"', '"'},
                    ["'"] = {"'", "'"},
                    ["{"] = {"{", "}"},
                    ["["] = {"[", "]"} }

local _closing_pairs = { '"', ")", "}", "]", "'"}

-- pronounced clozer
local function _closer(frag)
   local mebbe = false
   for _, cha in ipairs(_closing_pairs) do
      mebbe = mebbe or cha == frag
   end
   return mebbe
end

local function _no_insert(line, cursor, frag)
   if frag == line[cursor]
      and _closer(frag) then
      return false
   else
      return true
   end
end

function Txtbuf.insert(txtbuf, frag)
   local line = txtbuf.lines[txtbuf.cur_row]
   local wide_frag = utf8(frag)
   -- #deprecated
   -- in principle, we should be breaking up wide (paste) inputs in
   -- femto.
   --
   -- in reality this code is still invoked on paste.  Something to fix
   -- at some point...
   if wide_frag < #frag then -- a paste
      -- Normalize whitespace
      frag = gsub(frag, "\r\n", "\n"):gsub("\r", "\n"):gsub("\t", "   ")
      wide_frag = codepoints(frag)
   else
      wide_frag = false
   end
   -- #/deprecated
   if not wide_frag then
      if _frag_sub[frag] and _no_insert(line, txtbuf.cursor, frag) then
         -- add a closing symbol
         splice(line, txtbuf.cursor, _frag_sub[frag])
      elseif _no_insert(line, txtbuf.cursor, frag)then
         t_insert(line, txtbuf.cursor, frag)
      end
      txtbuf.cursor = txtbuf.cursor + 1
      return true
   else
      -- What if the fragment contains a newline? Don't we need to split it onto two lines of the txtbuf?
      -- Breaking up paste inputs might change how/where we handle this, but somehow or other we need to...
      splice(line, txtbuf.cursor, wide_frag)
      txtbuf.cursor = txtbuf.cursor + #wide_frag
      return true
   end

   return false
end






local ts_bw = (require "color").ts_bw

function Txtbuf.advance(txtbuf)
   -- Seems like this should be folded into insert(), as part of handling newlines?
   txtbuf.lines[#txtbuf.lines + 1] = {}
   txtbuf.cur_row = #txtbuf.lines
   txtbuf.cursor = 1
end












local remove = assert(table.remove)

local _del_by_pairs = { {"{", "}"},
                       {"'", "'"},
                       {'"', '"'},
                       {"[", "]"},
                       {"(", ")"} }

local function _isPaired(a, b)
   local pairing = false
   for _, bookends in ipairs(_del_by_pairs) do
      pairing = pairing or (a == bookends[1] and b == bookends[2])
   end
   return pairing
end

local function _deleteBack(txtbuf, cursor)
   local cursor, cur_row, lines = txtbuf.cursor, txtbuf.cur_row, txtbuf.lines
   if _isPaired(lines[cur_row][cursor - 1], lines[cur_row][cursor]) then
      remove(txtbuf.lines[cur_row], cursor)
      remove(txtbuf.lines[cur_row], cursor - 1)
   else
      remove(txtbuf.lines[cur_row], cursor - 1)
   end
   txtbuf.cursor = cursor - 1
end

function Txtbuf.d_back(txtbuf)
   local cursor, cur_row = txtbuf.cursor, txtbuf.cur_row
   if cursor > 1 then
      _deleteBack(txtbuf, cursor)
      return false
   elseif cur_row == 1 then
      return false
   else
      txtbuf:openRow(cur_row - 1)
      local new_cursor = #txtbuf.lines[cur_row - 1] + 1
      splice(txtbuf.lines[cur_row - 1],nil,txtbuf.lines[cur_row])
      remove(txtbuf.lines, cur_row)
      txtbuf.cur_row = cur_row - 1
      txtbuf.cursor = new_cursor
      return true
   end
end






function Txtbuf.d_fwd(txtbuf)
   local cursor, cur_row = txtbuf.cursor, txtbuf.cur_row
   if cursor <= #txtbuf.lines[cur_row] then
      remove(txtbuf.lines[txtbuf.cur_row], txtbuf.cursor)
      return false
   elseif cur_row == #txtbuf.lines then
      return false
   else
      txtbuf:openRow(cur_row + 1)
      splice(txtbuf.lines[cur_row],nil,txtbuf.lines[cur_row + 1])
      remove(txtbuf.lines, cur_row + 1)
      return true
   end
end










function Txtbuf.left(txtbuf, disp)
   local disp = disp or 1
   local moved = false
   if txtbuf.cursor - disp >= 1 then
      txtbuf.cursor = txtbuf.cursor - disp
      moved = true
   else
      txtbuf.cursor = 1
   end
   if not moved and txtbuf.cur_row ~= 1 then
      local cur_row = txtbuf.cur_row - 1
      txtbuf.cur_row = cur_row
      txtbuf.cursor = #txtbuf.lines[cur_row] + 1
   end

   return moved
end






function Txtbuf.right(txtbuf, disp)
   disp = disp or 1
   local moved = false
   local line = txtbuf.lines[txtbuf.cur_row]
   if txtbuf.cursor + disp <= #line + 1 then
      txtbuf.cursor = txtbuf.cursor + disp
      moved = true
   else
      txtbuf.cursor = #line + 1
   end

   if not moved and txtbuf.cur_row ~= txtbuf.lines then
      txtbuf.cur_row = txtbuf.cur_row + 1
      txtbuf.cursor = 1
   end

   return moved
end






























local function _constrain_cursor(txtbuf)
   if txtbuf.cursor > #txtbuf.lines[txtbuf.cur_row] + 1 then
      txtbuf.cursor = #txtbuf.lines[txtbuf.cur_row] + 1
   end
end

function Txtbuf.up(txtbuf)
   if txtbuf.cur_row == 1 then
      return false
   else
      txtbuf:switchRow(txtbuf.cur_row - 1)
      _constrain_cursor(txtbuf)
      return true
   end
end



function Txtbuf.down(txtbuf)
   if txtbuf.cur_row == #txtbuf.lines then
      return false
   else
      txtbuf:switchRow(txtbuf.cur_row + 1)
      _constrain_cursor(txtbuf)
      return true
   end
end







local sub = assert(string.sub)
local insert = assert(table.insert)
function Txtbuf.nl(txtbuf)
   -- Most txtbufs are one line, so we always evaluate from
   -- a one-liner, regardless of cursor location.
   local linum = #txtbuf.lines
   if linum == 1 then
      return true
   end
   local cursor = txtbuf.cursor
   local cur_row = txtbuf.cur_row
   -- these are the two default positions for up and down
   -- history search
   if cur_row == 1 and cursor > #txtbuf.lines[1] then
      return true
   end
   if cur_row == linum and cursor > #txtbuf.lines[linum] then
      return true
   end
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
   -- Clone to depth of 3 to get tb, tb.lines, and each lines
   local tb = cl(txtbuf, 3)
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


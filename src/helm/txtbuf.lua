


































































assert(meta)
local Codepoints = require "singletons/codepoints"
local lines = import("core/string", "lines")
local clone, collect, slice, splice =
   import("core/table", "clone", "collect", "slice", "splice")

local concat, insert, remove = assert(table.concat),
                               assert(table.insert),
                               assert(table.remove)






local Txtbuf = meta {}






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
   local closed_lines = {}
   for k, v in ipairs(txtbuf.lines) do
      closed_lines[k] = cat(v)
   end
   return concat(closed_lines, "\n")
end











function Txtbuf.currentPosition(txtbuf)
   local row, col = txtbuf.cursor.row, txtbuf.cursor.col
   return txtbuf.lines[row], col, row
end
















local core_math = require "core/math"
local bound, inbounds = assert(core_math.bound), assert(core_math.inbounds)

function Txtbuf.makeCursor(txtbuf, rowOrTable, col, basedOn)
   local row
   if type(rowOrTable) == "table" then
      row, col = rowOrTable.row, rowOrTable.col
   else
      row = rowOrTable
   end
   row = row or basedOn.row
   col = col or basedOn.col
   assert(inbounds(row, 1, #txtbuf.lines))
   txtbuf:openRow(row)
   assert(inbounds(col, 1, nil))
   col = bound(col, nil, #txtbuf.lines[row] + 1)
   return {row = row, col = col}
end

function Txtbuf.setCursor(txtbuf, rowOrTable, col)
   txtbuf.cursor = txtbuf:makeCursor(rowOrTable, col, txtbuf.cursor)
   txtbuf.cursor_changed = true
end









function Txtbuf.cursorIndex(txtbuf)
   local index = txtbuf.cursor.col
   for row = txtbuf.cursor.row - 1, 1, -1 do
      index = index + #txtbuf.lines[row] + 1
   end
   return index
end









function Txtbuf.openRow(txtbuf, row_num)
   if row_num < 1 or row_num > #txtbuf.lines then
      return nil
   end
   if type(txtbuf.lines[row_num]) == "string" then
      txtbuf.lines[row_num] = Codepoints(txtbuf.lines[row_num])
   end
   return txtbuf.lines[row_num], row_num
end







function Txtbuf.advance(txtbuf)
   txtbuf.lines[#txtbuf.lines + 1] = {}
   txtbuf.contents_changed = true
   txtbuf:setCursor(#txtbuf.lines, 1)
end









local _openers = { ["("] = ")",
                   ['"'] = '"',
                   ["'"] = "'",
                   ["{"] = "}",
                   ["["] = "]"}

local _closers = {}
for o, c in pairs(_openers) do
   _closers[c] = o
end

local function _should_insert(line, cursor, frag)
   return not (frag == line[cursor] and _closers[frag])
end

local function _should_pair(line, cursor, frag)
   -- Only consider inserting a pairing character if this is an "opener"
   if not _openers[frag] then return false end
   -- Translate end-of-line to the implied newline
   local next_char = line[cursor] or "\n"
   -- Insert a pair if we are before whitespace, or the next char is a
   -- closing brace--that is, a closing character that is different
   -- from its corresponding open character, i.e. not a quote
   return next_char:match("%s") or
      _closers[next_char] and _closers[next_char] ~= next_char
end

function Txtbuf.insert(txtbuf, frag)
   local line, cur_col = txtbuf.lines[txtbuf.cursor.row], txtbuf.cursor.col
   if _should_insert(line, cur_col, frag) then
      if _should_pair(line, cur_col, frag) then
         insert(line, cur_col, _openers[frag])
      end
      insert(line, cur_col, frag)
      txtbuf.contents_changed = true
   end
   txtbuf:setCursor(nil, cur_col + 1)
   return true
end









function Txtbuf.paste(txtbuf, frag)
   frag = frag:gsub("\t", "   ")
   local frag_lines = collect(lines, frag)
   local num_lines_before = #txtbuf.lines
   for i, frag_line in ipairs(frag_lines) do
      if i > 1 then txtbuf:nl() end
      local codes = Codepoints(frag_line)
      local line, cur_col, cur_row = txtbuf:currentPosition()
      splice(line, cur_col, codes)
      txtbuf:setCursor(nil, cur_col + #codes)
   end
   txtbuf.contents_changed = true
end








local function _is_paired(a, b)
   return _openers[a] == b
end

function Txtbuf.deleteBackward(txtbuf)
   local line, cur_col, cur_row = txtbuf:currentPosition()
   if cur_row == 1 and cur_col == 1 then
      return false
   end
   -- At this point we will definitely make a change
   txtbuf.contents_changed = true
   if cur_col > 1 then
      if _is_paired(line[cur_col - 1], line[cur_col]) then
         remove(line, cur_col)
      end
      remove(line, cur_col - 1)
      txtbuf:setCursor(nil, cur_col - 1)
      return false
   else
      txtbuf:openRow(cur_row - 1)
      local new_col = #txtbuf.lines[cur_row - 1] + 1
      splice(txtbuf.lines[cur_row - 1], nil, line)
      remove(txtbuf.lines, cur_row)
      txtbuf:setCursor(cur_row - 1, new_col)
      return true
   end
end






function Txtbuf.deleteForward(txtbuf)
   local line, cur_col, cur_row = txtbuf:currentPosition()
   if cur_row == #txtbuf.lines and cur_col > #line then
      return false
   end
   txtbuf.contents_changed = true
   if cur_col <= #line then
      remove(line, cur_col)
      return false
   else
      txtbuf:openRow(cur_row + 1)
      splice(line, nil, txtbuf.lines[cur_row + 1])
      remove(txtbuf.lines, cur_row + 1)
      return true
   end
end






function Txtbuf.killToEndOfLine(txtbuf)
   local line, cur_col, cur_row = txtbuf:currentPosition()
   if #line == cur_col then return false end
   txtbuf.contents_changed = true
   for _ = #line, cur_col, -1 do
      remove(line)
   end
   return true
end






function Txtbuf.killToBeginningOfLine(txtbuf)
   local line, cur_col, cur_row = txtbuf:currentPosition()
   local final, shift = #line, 1
   if final == shift then return false end
   txtbuf.contents_changed = true
   -- copy remainder, if any
   for i = cur_col, #line do
      line[shift] = line[i]
      shift = shift + 1
   end
   for i = shift, final do
      line[i] = nil
   end
   txtbuf:setCursor(cur_row, 1)
   return true
end







function Txtbuf.transposeLetter(txtbuf)
   local line, cur_col, cur_row = txtbuf:currentPosition()
   if cur_col == 1 then return false end
   local edge, left, right = #line == cur_col, cur_col - 1, cur_col
   local stash = line[right]
   line[right] = line[left]
   line[left] = stash
   if not edge then
      txtbuf:setCursor(cur_row, cur_col + 1)
   end
   txtbuf.contents_changed = true
   return true
end











function Txtbuf.left(txtbuf, disp)
   disp = disp or 1
   local line, new_col, new_row = txtbuf:currentPosition()
   new_col = new_col - disp
   while new_col < 1 do
      _, new_row = txtbuf:openRow(new_row - 1)
      if not new_row then
         txtbuf:setCursor(nil, 1)
         return false
      end
      new_col = #line + 1 + new_col
   end
   txtbuf:setCursor(new_row, new_col)
   return true
end






function Txtbuf.right(txtbuf, disp)
   disp = disp or 1
   local line, new_col, new_row = txtbuf:currentPosition()
   new_col = new_col + disp
   while new_col > #line + 1 do
      _, new_row = txtbuf:openRow(new_row + 1)
      if not new_row then
         txtbuf:setCursor(nil, #line + 1)
         return false
      end
      new_col = new_col - (#txtbuf.lines[new_row - 1] + 1)
   end
   txtbuf:setCursor(new_row, new_col)
   return true
end






function Txtbuf.startOfLine(txtbuf)
   txtbuf:setCursor(nil, 1)
end

function Txtbuf.endOfLine(txtbuf)
   txtbuf:setCursor(nil, #txtbuf.lines[txtbuf.cursor.row] + 1)
end









function Txtbuf.startOfText(txtbuf)
   txtbuf:setCursor(1, 1)
end

function Txtbuf.endOfText(txtbuf)
   txtbuf:setCursor(#txtbuf.lines, #txtbuf.lines[#txtbuf.lines] + 1)
end




























local match = assert(string.match)

function Txtbuf.leftToBoundary(txtbuf, pattern, reps)
   reps = reps or 1
   local found_other_char = false
   local moved = false
   local line, search_pos, search_row = txtbuf:currentPosition()
   local search_char
   while true do
      search_char = search_pos == 1 and "\n" or line[search_pos - 1]
      if not match(search_char, pattern) then
         found_other_char = true
      elseif found_other_char then
         reps = reps - 1
         if reps == 0 then break end
         found_other_char = false
      end
      if search_pos == 1 then
         if search_row == 1 then break end
         line, search_row = txtbuf:openRow(search_row - 1)
         search_pos = #line + 1
      else
         search_pos = search_pos - 1
      end
      moved = true
   end
   txtbuf:setCursor(search_row, search_pos)
   return moved
end

function Txtbuf.rightToBoundary(txtbuf, pattern, reps)
   reps = reps or 1
   local found_other_char = false
   local moved = false
   local line, search_pos, search_row = txtbuf:currentPosition()
   local search_char
   while true do
      search_char = search_pos > #line and "\n" or line[search_pos]
      if not match(search_char, pattern) then
         found_other_char = true
      elseif found_other_char then
         reps = reps - 1
         if reps == 0 then break end
         found_other_char = false
      end
      if search_pos > #line then
         if search_row == #txtbuf.lines then break end
         line, search_row = txtbuf:openRow(search_row + 1)
         search_pos = 1
      else
         search_pos = search_pos + 1
      end
      moved = true
   end
   txtbuf:setCursor(search_row, search_pos)
   return moved
end











function Txtbuf.firstNonWhitespace(txtbuf)
   local line = txtbuf.lines[txtbuf.cursor.row]
   local new_col = 1
   while new_col <= #line do
      if match(line[new_col], '%S') then
         txtbuf:setCursor(nil, new_col)
         return true
      end
      new_col = new_col + 1
   end
   return false
end







function Txtbuf.leftWordAlpha(txtbuf, reps)
   return txtbuf:leftToBoundary('%W', reps)
end

function Txtbuf.rightWordAlpha(txtbuf, reps)
   return txtbuf:rightToBoundary('%W', reps)
end

function Txtbuf.leftWordWhitespace(txtbuf, reps)
   return txtbuf:leftToBoundary('%s', reps)
end

function Txtbuf.rightWordWhitespace(txtbuf, reps)
   return txtbuf:rightToBoundary('%s', reps)
end























function Txtbuf.up(txtbuf)
   if not txtbuf:openRow(txtbuf.cursor.row - 1) then
      txtbuf:setCursor(nil, 1)
      return false
   end
   txtbuf:setCursor(txtbuf.cursor.row - 1, nil)
   return true
end



function Txtbuf.down(txtbuf)
   if not txtbuf:openRow(txtbuf.cursor.row + 1) then
      txtbuf:setCursor(nil, #txtbuf.lines[txtbuf.cursor.row] + 1)
      return false
   end
   txtbuf:setCursor(txtbuf.cursor.row + 1, nil)
   return true
end









function Txtbuf.nl(txtbuf)
   line, cur_col, cur_row = txtbuf:currentPosition()
   -- split the line
   local first = slice(line, 1, cur_col - 1)
   local second = slice(line, cur_col)
   txtbuf.lines[cur_row] = first
   insert(txtbuf.lines, cur_row + 1, second)
   txtbuf.contents_changed = true
   txtbuf:setCursor(cur_row + 1, 1)
   return false
end








function Txtbuf.shouldEvaluate(txtbuf)
   -- Most txtbufs are one line, so we always evaluate from
   -- a one-liner, regardless of cursor location.
   local linum = #txtbuf.lines
   if linum == 1 then
      return true
   end
   local _, cur_col, cur_row = txtbuf:currentPosition()
   -- Evaluate if we are at the end of the first or last line (the default
   -- positions after scrolling up or down in the history)
   if (cur_row == 1 or cur_row == linum) and cur_col > #txtbuf.lines[cur_row] then
      return true
   end
end





function Txtbuf.suspend(txtbuf)
   for i, v in ipairs(txtbuf.lines) do
      txtbuf.lines[i] = cat(v)
   end
   return txtbuf
end



function Txtbuf.resume(txtbuf)
   txtbuf:openRow(txtbuf.cursor.row)
   return txtbuf
end



function Txtbuf.clone(txtbuf)
   -- Clone to depth of 3 to get tb, tb.lines, and each lines
   local tb = clone(txtbuf, 3)
   return tb:resume()
end







local function new(str)
   str = str or ""
   local txtbuf = meta(Txtbuf)
   local lines = collect(lines, str)
   if #lines == 0 then
      lines[1] = {}
   end
   txtbuf.lines = lines
   txtbuf:endOfText()
   txtbuf.contents_changed = false
   txtbuf.cursor_changed = false
   return txtbuf
end

Txtbuf.idEst = new



return new

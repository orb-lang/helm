











































































assert(meta)
local Codepoints = require "singletons/codepoints"
local lines = import("core/string", "lines")
local clone, collect, slice, splice =
   import("core/table", "clone", "collect", "slice", "splice")

local concat, insert, remove = assert(table.concat),
                               assert(table.insert),
                               assert(table.remove)






local Rainbuf = require "helm:rainbuf"
local Txtbuf = Rainbuf:inherit()






local function cat(l)
   if l == nil then
      return ""
   elseif type(l) == "string" then
      return l
   elseif type(l) == "table" then
      return concat(l)
   else
      error("called private fn cat with type" .. type(l))
   end
end




function Txtbuf.__tostring(txtbuf)
   local closed_lines = {}
   for k, v in ipairs(txtbuf) do
      closed_lines[k] = cat(v)
   end
   return concat(closed_lines, "\n")
end














function Txtbuf.currentPosition(txtbuf)
   local row, col = txtbuf.cursor:rowcol()
   return txtbuf[row], col, row
end
















local core_math = require "core/math"
local clamp, inbounds = assert(core_math.clamp), assert(core_math.inbounds)
local Point = require "anterm/point"

function Txtbuf.makeCursor(txtbuf, rowOrTable, col, basedOn)
   local row
   if type(rowOrTable) == "table" then
      row, col = rowOrTable.row, rowOrTable.col
   else
      row = rowOrTable
   end
   row = row or basedOn.row
   col = col or basedOn.col
   assert(inbounds(row, 1, #txtbuf))
   txtbuf:openRow(row)
   assert(inbounds(col, 1, nil))
   col = clamp(col, nil, #txtbuf[row] + 1)
   return Point(row, col)
end

function Txtbuf.setCursor(txtbuf, rowOrTable, col)
   txtbuf.cursor = txtbuf:makeCursor(rowOrTable, col, txtbuf.cursor)
   txtbuf.cursor_changed = true
end










function Txtbuf.cursorIndex(txtbuf)
   local index = txtbuf.cursor.col
   for row = txtbuf.cursor.row - 1, 1, -1 do
      index = index + #txtbuf[row] + 1
   end
   return index
end










function Txtbuf.beginSelection(txtbuf)
   txtbuf.mark = clone(txtbuf.cursor)
end








function Txtbuf.clearSelection(txtbuf)
   if txtbuf:hasSelection() then
      txtbuf.cursor_changed = true
   end
   txtbuf.mark = nil
end












function Txtbuf.hasSelection(txtbuf)
   if not txtbuf.mark then return false end
   if txtbuf.mark.row == txtbuf.cursor.row
      and txtbuf.mark.col == txtbuf.cursor.col then
      txtbuf.mark = nil
      return false
   else
      return true
   end
end












function Txtbuf.selectionStart(txtbuf)
   if not txtbuf:hasSelection() then return nil end
   local c, m = txtbuf.cursor, txtbuf.mark
   if m.row < c.row or
      (m.row == c.row and m.col < c.col) then
      return m.col, m.row
   else
      return c.col, c.row
   end
end

function Txtbuf.selectionEnd(txtbuf)
   if not txtbuf:hasSelection() then return nil end
   local c, m = txtbuf.cursor, txtbuf.mark
   if m.row > c.row or
      (m.row == c.row and m.col > c.col) then
      return m.col, m.row
   else
      return c.col, c.row
   end
end













function Txtbuf.openRow(txtbuf, row_num)
   if row_num < 1 or row_num > #txtbuf then
      return nil
   end
   if type(txtbuf[row_num]) == "string" then
      txtbuf[row_num] = Codepoints(txtbuf[row_num])
   end
   return txtbuf[row_num], row_num
end










function Txtbuf.nl(txtbuf)
   line, cur_col, cur_row = txtbuf:currentPosition()
   -- split the line
   local first = slice(line, 1, cur_col - 1)
   local second = slice(line, cur_col)
   txtbuf[cur_row] = first
   insert(txtbuf, cur_row + 1, second)
   txtbuf.contents_changed = true
   txtbuf:setCursor(cur_row + 1, 1)
   return false
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
   local line, cur_col = txtbuf[txtbuf.cursor.row], txtbuf.cursor.col
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
   for i, frag_line in ipairs(frag_lines) do
      if i > 1 then txtbuf:nl() end
      local codes = Codepoints(frag_line)
      local line, cur_col, cur_row = txtbuf:currentPosition()
      splice(line, cur_col, codes)
      txtbuf:setCursor(nil, cur_col + #codes)
   end
   txtbuf.contents_changed = true
end
















local deleterange = import("core/table", "deleterange")
function Txtbuf.killSelection(txtbuf)
   if not txtbuf:hasSelection() then
      return false
   end
   txtbuf.contents_changed = true
   local start_col, start_row = txtbuf:selectionStart()
   local end_col, end_row = txtbuf:selectionEnd()
   if start_row == end_row then
      -- Deletion within a line, just remove some chars
      deleterange(txtbuf[start_row], start_col, end_col - 1)
   else
      -- Grab both lines--we're about to remove the end line
      local start_line, end_line = txtbuf[start_row], txtbuf[end_row]
      deleterange(txtbuf, start_row + 1, end_row)
      -- Splice lines together
      for i = start_col, #start_line do
         start_line[i] = nil
      end
      for i = end_col, #end_line do
         insert(start_line, end_line[i])
      end
   end
   -- Cursor always ends up at the start of the formerly-selected area
   txtbuf:setCursor(start_row, start_col)
   -- No selection any more
   txtbuf:clearSelection()
end








local function _delete_for_motion(motionName)
   return function(txtbuf, ...)
      txtbuf:beginSelection()
      txtbuf[motionName](txtbuf, ...)
      return txtbuf:killSelection()
   end
end

for delete_name, motion_name in pairs({
   killForward = "right",
   killToEndOfLine = "endOfLine",
   killToBeginningOfLine = "startOfLine",
   killToEndOfWord = "rightWordAlpha",
   killToBeginningOfWord = "leftWordAlpha"
}) do
   Txtbuf[delete_name] = _delete_for_motion(motion_name)
end










local function _is_paired(a, b)
   -- a or b might be out-of-bounds, and if a is not a brace and b is nil,
   -- we would incorrectly answer true, so check that both a and b are present
   return a and b and _openers[a] == b
end

function Txtbuf.killBackward(txtbuf, disp)
   disp = disp or 1
   local line, cur_col, cur_row = txtbuf:currentPosition()
   -- Only need to check the character immediately to the left of the cursor
   -- since if we encounter paired braces later, we will delete the
   -- closing brace first anyway
   if _is_paired(line[cur_col - 1], line[cur_col]) then
      txtbuf:right()
      disp = disp + 1
   end
   txtbuf:beginSelection()
   txtbuf:left(disp)
   txtbuf:killSelection()
end













function Txtbuf.left(txtbuf, disp)
   disp = disp or 1
   local line, new_col, new_row = txtbuf:currentPosition()
   new_col = new_col - disp
   while new_col < 1 do
      line, new_row = txtbuf:openRow(new_row - 1)
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
      new_col = new_col - #line - 1
      line = txtbuf[new_row]
   end
   txtbuf:setCursor(new_row, new_col)
   return true
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
      txtbuf:setCursor(nil, #txtbuf[txtbuf.cursor.row] + 1)
      return false
   end
   txtbuf:setCursor(txtbuf.cursor.row + 1, nil)
   return true
end






function Txtbuf.startOfLine(txtbuf)
   txtbuf:setCursor(nil, 1)
end

function Txtbuf.endOfLine(txtbuf)
   txtbuf:setCursor(nil, #txtbuf[txtbuf.cursor.row] + 1)
end








function Txtbuf.startOfText(txtbuf)
   txtbuf:setCursor(1, 1)
end

function Txtbuf.endOfText(txtbuf)
   txtbuf:setCursor(#txtbuf, #txtbuf[#txtbuf] + 1)
end























local match = assert(string.match)

function Txtbuf.scanFor(txtbuf, pattern, reps, forward)
   local change = forward and 1 or -1
   reps = reps or 1
   local found_other_char, moved = false, false
   local line, cur_col, cur_row = txtbuf:currentPosition()
   local search_pos, search_row = cur_col, cur_row
   local search_char
   local epsilon = forward and 0 or -1
   while true do
      local at_boundary = (forward and search_pos > #line)
                       or (not forward and search_pos == 1)
      search_char = at_boundary and "\n" or line[search_pos + epsilon]
      if not match(search_char, pattern) then
         found_other_char = true
      elseif found_other_char then
         reps = reps - 1
         if reps == 0 then break end
         found_other_char = false
      end
      if at_boundary then
         -- break out on txtbuf boundaries
         if search_row == (forward and #txtbuf or 1) then break end
         line, search_row = txtbuf:openRow(search_row + change)
         search_pos = forward and 1 or #line + 1
      else
         search_pos = search_pos + change
      end
      moved = true
   end

   return moved, search_pos - cur_col, search_row - cur_row
end








function Txtbuf.leftToBoundary(txtbuf, pattern, reps)
   local line, cur_col, cur_row = txtbuf:currentPosition()
   local moved, colΔ, rowΔ = txtbuf:scanFor(pattern, reps, false)
   if moved then
      txtbuf:setCursor(cur_row + rowΔ, cur_col + colΔ)
      return true
   else
      return false
   end
end

function Txtbuf.rightToBoundary(txtbuf, pattern, reps)
   local line, cur_col, cur_row = txtbuf:currentPosition()
   local moved, colΔ, rowΔ = txtbuf:scanFor(pattern, reps, true)
   if moved then
      txtbuf:setCursor(cur_row + rowΔ, cur_col + colΔ)
      return true
   else
      return false
   end
end









function Txtbuf.firstNonWhitespace(txtbuf)
   local line = txtbuf[txtbuf.cursor.row]
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























function Txtbuf.transposeLetter(txtbuf)
   local line, cur_col, cur_row = txtbuf:currentPosition()
   if cur_col == 1 then return false end
   if cur_col == 2 and #line == 1 then return false end
   local left, right = cur_col - 1, cur_col
   if cur_col == #line + 1 then
      left, right = left - 1, right - 1
   end
   local stash = line[right]
   line[right] = line[left]
   line[left] = stash
   txtbuf:setCursor(nil, right + 1)
   txtbuf.contents_changed = true
   return true
end









function Txtbuf.shouldEvaluate(txtbuf)
   -- Most txtbufs are one line, so we always evaluate from
   -- a one-liner, regardless of cursor location.
   local linum = #txtbuf
   if linum == 1 then
      return true
   end
   local _, cur_col, cur_row = txtbuf:currentPosition()
   -- Evaluate if we are at the end of the first or last line (the default
   -- positions after scrolling up or down in the history)
   if (cur_row == 1 or cur_row == linum) and cur_col > #txtbuf[cur_row] then
      return true
   end
end









function Txtbuf.initComposition(txtbuf, cols)
   txtbuf:super"initComposition"(cols)
   txtbuf.render_row = 1
end






local c = assert(require "singletons:color" . color)
function Txtbuf._composeOneLine(txtbuf)
   if txtbuf.render_row > #txtbuf then return nil end
   local tokens = txtbuf:tokens(txtbuf.render_row)
   local suggestion = txtbuf.active_suggestions
      and txtbuf.active_suggestions:selectedItem()
   for i, tok in ipairs(tokens) do
      -- If suggestions are active and one is highlighted,
      -- display it in grey instead of what the user has typed so far
      -- Note this only applies once Tab has been pressed, as until then
      -- :selectedItem() will be nil
      if suggestion and tok.cursor_offset then
         tokens[i] = txtbuf.active_suggestions:highlight(suggestion, 80, c)
      else
         tokens[i] = tok:toString(c)
      end
   end
   txtbuf.render_row = txtbuf.render_row + 1
   return concat(tokens)
end








function Txtbuf.tokens(txtbuf, row)
   if row then
      local cursor_col = txtbuf.cursor.row == row
         and txtbuf.cursor.col or 0
      return txtbuf.lex(cat(txtbuf[row]), cursor_col)
   else
      return txtbuf.lex(tostring(txtbuf), txtbuf:cursorIndex())
   end
end





function Txtbuf.suspend(txtbuf)
   for i, v in ipairs(txtbuf) do
      txtbuf[i] = cat(v)
   end
   return txtbuf
end



function Txtbuf.resume(txtbuf)
   txtbuf:openRow(txtbuf.cursor.row)
   return txtbuf
end



function Txtbuf.clone(txtbuf)
   -- Clone the lines as well as the Txtbuf itself
   local tb = clone(txtbuf, 2)
   return tb:resume()
end






function Txtbuf._init(txtbuf)
   txtbuf:super"_init"()
   -- Txtbuf needs to re-render in most event-loop cycles, detecting
   -- whether a re-render is actually needed is tricky,
   -- and it's reasonably cheap to just *always* re-render, so...
   txtbuf.live = true
   txtbuf.contents_changed = false
   txtbuf.cursor_changed = false
end

function Txtbuf.replace(txtbuf, str)
   str = str or ""
   -- We always have at least one line--will be overwritten
   -- if there's actual content provided in str
   txtbuf[1] = ""
   local i = 1
   for line in lines(str) do
      txtbuf[i] = line
      i = i + 1
   end
   for j = i, #txtbuf do
      txtbuf[j] = nil
   end
   txtbuf.contents_changed = true
   txtbuf:endOfText()
   return txtbuf
end



local Txtbuf_class = setmetatable({}, Txtbuf)
Txtbuf.idEst = Txtbuf_class

return Txtbuf_class


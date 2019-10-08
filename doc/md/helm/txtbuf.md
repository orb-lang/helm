# Txtbuf

This is not much more than an ordinary array of lines that has a bit of
awareness, mostly about which lines have cursors and which don't.


I'll circle back for quipu but I want a basic editor as soon as possible. The
interaction dynamics need to be worked out right away, plus I want to use it!


Plan: A line that has a cursor on it, and there can be many, gets 'opened'
into a grid of characters.  Lines stay open until the txtbuf is suspended,
at which point they are all closed.


A closed line is just a string.


## Interface


### Instance fields

-  lines :  An array of strings (closed lines), or arrays containing codepoints
           (string fragments) (open lines).


-  cursor :  A table representing the cursor position:
   - row : Row containing the cursor. Valid values are 1 to #lines.
   - col : Number of fragments to skip before an insertion.
           Valid values are 1 to #lines[row] + 1.
   Code uing this MUST NOT modify the structure directly--clone it if you need to.
   Often it is most convenient to handle it as two separate local variables,
   which can be retrieved in one step with getCursor(). cur_row and cur_col
   are sensible names.
   DO NOT assign directly to this field--use setCursor().


The intention is that all of these fields are manipulated internally: the
codebase doesn't completely respect this, yet, but it should.


This will let us expand, for instance, the definition of ``cursor`` to allow for
an array of cursors, in the event that there's more than one, without exposing
this elaboration to the rest of the system.


The ``txtbuf`` is also a candidate for full replacement with the quipu data
structure, so the more we can encapsulate its region of responsiblity, the
cleaner that transition can be.


#### Instance fields to be added

- mark :  A structure like ``cursor``, representing the fixed end of a region,
          with the ``cursor`` field being the mobile end. Note that ``cursor`` may
          be earlier than ``mark``, respresenting the case where selection
          proceeded backwards, e.g. by pressing Shift+Left. The "cursor" end
          is always the one that moves when executing additional motions.


          Mutation of these should be encapsulated such that they can be
          combined into a "region" structure, of which there may eventually be
          multiple instances, during for instance search and replace.
- disp :  Array of numbers, representing the furthest-right column which
          may be reached by printing the corresponding row. Not equivalent
          to #lines[n] as one codepoint != one column.

#### dependencies

```lua
assert(meta)
local codepoints = assert(string.codepoints)
local gsub = assert(string.gsub)
local sub = assert(string.sub)

local table_clone = assert(table.clone)
local concat = assert(table.concat)
local insert, splice = assert(table.insert), assert(table.splice)
local remove = assert(table.remove)
```
## Methods

```lua
local Txtbuf = meta {}
```
### Txtbuf.__tostring(txtbuf)

```lua

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
```
```lua

function Txtbuf.__tostring(txtbuf)
   local closed_lines = table_clone(txtbuf.lines)
   for k, v in ipairs(closed_lines) do
      closed_lines[k] = cat(v)
   end
   return concat(closed_lines, "\n")
end
```
### Txtbuf:getCursor()

Convenience method to break the ``cursor`` into two local variables,
e.g. local cur_row, cur_col = txtbuf:getCursor()

```lua

local function _split_cursor(cursor)
   return cursor.row, cursor.col
end

function Txtbuf.getCursor(txtbuf)
   return _split_cursor(txtbuf.cursor)
end

```
### Txtbuf:setCursor(rowOrTable, col)

Set the ``cursor``, ensuring that the value is not shared with the caller.
Accepts either a cursor-like table, or two arguments representing ``row`` and ``col``.
Either ``row`` or ``col`` may be nil, in which case the current value is retained.


Performs bounds-checking of the proposed new values. Row out-of-bounds or
col < 1 is an error, but col > row length is constrained to be in bounds.


Also opens the row to which the cursor is being moved.

```lua

local bound, inbounds = assert(math.bound), assert(math.inbounds)

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
end

```
### Txtbuf:openRow(row_num)

Opens the row at index ``row_num`` for editing, breaking it into a grid of characters.
Answers the newly-opened line and index, or nil if the index is out of bounds.

```lua

function Txtbuf.openRow(txtbuf, row_num)
   if row_num < 1 or row_num > #txtbuf.lines then
      return nil
   end
   if type(txtbuf.lines[row_num]) == "string" then
      txtbuf.lines[row_num] = codepoints(txtbuf.lines[row_num])
   end
   return txtbuf.lines[row_num], row_num
end

```
### Txtbuf:advance()

```lua

function Txtbuf.advance(txtbuf)
   txtbuf.lines[#txtbuf.lines + 1] = {}
   txtbuf:setCursor(#txtbuf.lines, 1)
end
```
### Txtbuf:insert(frag)

```lua

local _brace_pairs = { ["("] = ")",
                       ['"'] = '"',
                       ["'"] = "'",
                       ["{"] = "}",
                       ["["] = "]"}
-- pronounced clozer
local function _is_closer(frag)
   for _, cha in pairs(_brace_pairs) do
      if cha == frag then return true end
   end
   return false
end

local function _should_insert(line, cursor, frag)
   return not (frag == line[cursor] and _is_closer(frag))
end

function Txtbuf.insert(txtbuf, frag)
   local line, cur_col = txtbuf.lines[txtbuf.cursor.row], txtbuf.cursor.col
   if _should_insert(line, cur_col, frag) then
      if _brace_pairs[frag] then
         insert(line, cur_col, _brace_pairs[frag])
      end
      insert(line, cur_col, frag)
   end
   txtbuf:setCursor(nil, cur_col + 1)
   return true
end
```
### Txtbuf:deleteBackward()

The return value tells us if we have one less line, since we need to
clear it off the screen (true of deleteForward as well).

```lua

local function _is_paired(a, b)
   return _brace_pairs[a] == b
end

function Txtbuf.deleteBackward(txtbuf)
   local cur_row, cur_col = txtbuf:getCursor()
   local line = txtbuf.lines[cur_row]
   if cur_col > 1 then
      if _is_paired(line[cur_col - 1], line[cur_col]) then
         remove(line, cur_col)
      end
      remove(line, cur_col - 1)
      txtbuf:setCursor(nil, cur_col - 1)
      return false
   elseif cur_row == 1 then
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
```
### Txtbuf:deleteForward()

```lua
function Txtbuf.deleteForward(txtbuf)
   local cur_row, cur_col = txtbuf:getCursor()
   if cur_col <= #txtbuf.lines[cur_row] then
      remove(txtbuf.lines[cur_row], cur_col)
      return false
   elseif cur_row == #txtbuf.lines then
      return false
   else
      txtbuf:openRow(cur_row + 1)
      splice(txtbuf.lines[cur_row], nil, txtbuf.lines[cur_row + 1])
      remove(txtbuf.lines, cur_row + 1)
      return true
   end
end
```
### Txtbuf:left(disp), Txtbuf:right(disp)

These methods shift a cursor left or right, handling line breaks internally.


``disp`` is a number of codepoints to shift.

```lua

function Txtbuf.left(txtbuf, disp)
   disp = disp or 1
   local new_row, new_col = txtbuf:getCursor()
   new_col = new_col - disp
   while new_col < 1 do
      _, new_row = txtbuf:openRow(new_row - 1)
      if not new_row then
         txtbuf:setCursor(nil, 1)
         return false
      end
      new_col = #txtbuf.lines[new_row] + 1 + new_col
   end
   txtbuf:setCursor(new_row, new_col)
   return true
end
```
### Txtbuf:right(disp)

```lua
function Txtbuf.right(txtbuf, disp)
   disp = disp or 1
   local new_row, new_col = txtbuf:getCursor()
   new_col = new_col + disp
   while new_col > #txtbuf.lines[new_row] + 1 do
      _, new_row = txtbuf:openRow(new_row + 1)
      if not new_row then
         txtbuf:setCursor(nil, #txtbuf.lines[txtbuf.cursor.row] + 1)
         return false
      end
      new_col = new_col - (#txtbuf.lines[new_row - 1] + 1)
   end
   txtbuf:setCursor(new_row, new_col)
   return true
end
```
### Txtbuf:startOfLine(), Txtbuf:endOfLine()

```lua

function Txtbuf.startOfLine(txtbuf)
   txtbuf:setCursor(nil, 1)
end

function Txtbuf.endOfLine(txtbuf)
   txtbuf:setCursor(nil, #txtbuf.lines[txtbuf.cursor.row] + 1)
end

```
### Txtbuf:startOfText(), Txtbuf:endOfText()

Moves to the very beginning or end of the buffer.

```lua

function Txtbuf.startOfText(txtbuf)
   txtbuf:setCursor(1, 1)
end

function Txtbuf.endOfText(txtbuf)
   txtbuf:setCursor(#txtbuf.lines, #txtbuf.lines[#txtbuf.lines] + 1)
end

```
### Txtbuf:rightToBoundary(pattern, reps), Txtbuf:leftToBoundary(pattern, reps)

Move the cursor until it "hits" a character matching ``pattern``, after
encountering at least one character **not** matching ``pattern``. Stops with the
cursor on the matching character when moving right, or one cell ahead of it
when moving left, i.e. with the cursor "between" a non-matching character
and a matching one. Used as the basis for word (alphanumeric) and
Word (whitespace-separated) motions.


- #parameters


   - pattern: A pattern matching character(s) to stop at. Generally either a
              single character or a single character class, e.g. %W
   - reps:    Number of times to repeat the motion


- To be added later:


  - mark:  A boolean: if true, the Txtbuf is annotated with a 'mark' defining
           a region.  The first cursor is stored as the mark origin, and the
           second cursor is given the 'cursor' slot on the txtbuf.


           This lets us define a generalized method to kill or yank the region.

```lua

local match = assert(string.match)

function Txtbuf.leftToBoundary(txtbuf, pattern, reps)
   reps = reps or 1
   local found_other_char = false
   local moved = false
   local search_row, search_pos = txtbuf:getCursor()
   local line = txtbuf.lines[search_row]
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
   local search_row, search_pos = txtbuf:getCursor()
   local line = txtbuf.lines[search_row]
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

```
### Txtbuf:firstNonWhitespace()

Moves to the first non-whitespace character of the current line. Return value
indicates whether such a character exists. Does not move the cursor if the
line is empty or all whitespace.

```lua

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

```
### Txtbuf:leftWordAlpha(reps), Txtbuf:rightWordAlpha(reps), Txtbuf:leftWordWhitespace(reps), Txtbuf:rightWordWhitespace(reps)

```lua

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

```
### Txtbuf:replace(frag)

Replaces the character to the right of the cursor with the given codepoint.


This is called ``frag`` as a reminder that, a) it's variable width and b) to
really nail displacement we need to be looking up displacements in some kind
of region-defined lookup table.

### Txtbuf:up(), Txtbuf:down()

Moves the cursor up or down a line, or to the beginning of the first line or
end of the last line if there is no line above/below.


Returns whether it was able to move to a different line, i.e. false in the
case of moving to the beginning/end of the first/last line.

```lua

function Txtbuf.up(txtbuf)
   if not txtbuf:openRow(txtbuf.cursor.row - 1) then
      txtbuf:setCursor(nil, 1)
      return false
   end
   txtbuf:setCursor(txtbuf.cursor.row - 1, nil)
   return true
end
```
```lua
function Txtbuf.down(txtbuf)
   if not txtbuf:openRow(txtbuf.cursor.row + 1) then
      txtbuf:setCursor(nil, #txtbuf.lines[txtbuf.cursor.row] + 1)
      return false
   end
   txtbuf:setCursor(txtbuf.cursor.row + 1, nil)
   return true
end
```
### Txtbuf:nl()

Either splits a line or (more usually) evaluates.

```lua
function Txtbuf.nl(txtbuf)
   -- Most txtbufs are one line, so we always evaluate from
   -- a one-liner, regardless of cursor location.
   local linum = #txtbuf.lines
   if linum == 1 then
      return true
   end
   local cur_row, cur_col = txtbuf:getCursor()
   -- Evaluate if we are at the end of the first or last line (the default
   -- positions after scrolling up or down in the history)
   if (cur_row == 1 or cur_row == linum) and cur_col > #txtbuf.lines[cur_row] then
      return true
   end
   -- split the line
   local line = concat(txtbuf.lines[cur_row])
   local first = sub(line, 1, cur_col - 1)
   local second = sub(line, cur_col)
   txtbuf.lines[cur_row] = codepoints(first)
   insert(txtbuf.lines, cur_row + 1, codepoints(second))
   txtbuf:setCursor(cur_row + 1, 1)
   return false
end
```
### Txtbuf:suspend(), Txtbuf:resume()



```lua
function Txtbuf.suspend(txtbuf)
   for i, v in ipairs(txtbuf.lines) do
      txtbuf.lines[i] = cat(v)
   end
   return txtbuf
end
```
```lua
function Txtbuf.resume(txtbuf)
   txtbuf:openRow(txtbuf.cursor.row)
   return txtbuf
end
```
```lua

function Txtbuf.clone(txtbuf)
   -- Clone to depth of 3 to get tb, tb.lines, and each lines
   local tb = table_clone(txtbuf, 3)
   return tb:resume()
end
```
### new

```lua

local collect = assert(table.collect)
local lines = assert(string.lines)

local function new(str)
   str = str or ""
   local txtbuf = meta(Txtbuf)
   local lines = collect(lines, str)
   if #lines == 0 then
      lines[1] = {}
   end
   txtbuf.lines = lines
   txtbuf:endOfText()
   return txtbuf
end

Txtbuf.idEst = new
```
```lua
return new
```

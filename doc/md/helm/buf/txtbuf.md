# Txtbuf

A `Rainbuf` specialized for displaying editable text, with optional
syntax highlighting\. This is not much more than an ordinary array of lines
that has a bit of awareness, mostly about which lines have cursors\.

I'll circle back for quipu but I want a basic editor as soon as possible\. The
interaction dynamics need to be worked out right away, plus I want to use it\!

Plan: A line that has a cursor on it, and there can be many, gets 'opened'
into a grid of characters\.  Lines stay open until the txtbuf is suspended,
at which point they are all closed\.

A closed line is just a string\.


## Interface


### Instance fields


-  <array portion> :  An array of strings \(closed lines\), or arrays containing
    codepoints \(string fragments\) \(open lines\)\.


-  cursor :  A <Point> representing the cursor position:
   - row : Row containing the cursor\. Valid values are 1 to \#lines\.
   - col : Number of fragments to skip before an insertion\.
       Valid values are 1 to \#lines\[row\] \+ 1\.

   These fields shouldn't be written to, use `txtbuf:setCursor()` which will
   check bounds\.  They may be retrieved, along with the line, with
   `txtbuf:currentPosition()`\.


- desired\_col : The column where the cursor "should" be, even if this is
    out\-of\-bounds in the current row\-\-used to retain a "memory"
    of where we were when moving from a long line, to a shorter
    one, back to a longer one\.


-  mark :  A structure like `cursor`, representing the fixed end of a region,
    with the `cursor` field being the mobile end\. Note that `cursor` may
    be earlier than `mark`, respresenting the case where selection
    proceeded backwards, e\.g\. by pressing Shift\+Left\. The "cursor" end
    is always the one that moves when executing additional motions\.

    Mutation of these should be encapsulated such that they can be
    combined into a "region" structure, of which there may eventually be
    multiple instances, during for instance search and replace\.


-  cursor\_changed :   A flag indicating whether the cursor has changed since
    the flag was last reset\.

-  contents\_changed : Similar flag for whether the actual contents of the
    buffer have changed\.


-  lex :  A function accepting a string and returning an array of Tokens,
    used by the Txtbuf to provide syntax highlighting\.


-  render\_row : Index of the row being rendered \(Rainbuf implementation detail\)


-  active\_suggestions : `SelectionList` of active suggestions, if any, provided

The intention is that all of these fields are manipulated internally: the
codebase doesn't completely respect this, yet, but it should\.

This will let us expand, for instance, the definition of `cursor` to allow for
an array of cursors, in the event that there's more than one, without exposing
this elaboration to the rest of the system\.

The `txtbuf` is also a candidate for full replacement with the quipu data
structure, so the more we can encapsulate its region of responsiblity, the
cleaner that transition can be\.


#### Instance fields to be added


- disp :  Array of numbers, representing the furthest\-right column which
    may be reached by printing the corresponding row\. Not equivalent
    to \#lines\[n\] as one codepoint \!= one column\.

#### dependencies

```lua
assert(meta)
local Codepoints = require "singletons/codepoints"
local lines = import("core/string", "lines")
local clone, collect, slice, splice =
   import("core/table", "clone", "collect", "slice", "splice")

local concat, insert, remove = assert(table.concat),
                               assert(table.insert),
                               assert(table.remove)
```


## Methods

```lua
local Rainbuf = require "helm:buf/rainbuf"
local Txtbuf = Rainbuf:inherit()
```

### Txtbuf\.\_\_tostring\(txtbuf\)

```lua

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
```

```lua

function Txtbuf.__tostring(txtbuf)
   local closed_lines = {}
   for k, v in ipairs(txtbuf) do
      closed_lines[k] = cat(v)
   end
   return concat(closed_lines, "\n")
end
```


### Txtbuf:contentsChanged\(\)

Notification that the contents of the Txtbuf have changed\.
Clear our render cache, and set a flag for the Modeselektor to check
and notify others\.

```lua
function Txtbuf.contentsChanged(txtbuf)
   txtbuf.contents_changed = true
   txtbuf:clearCaches()
end
```


### Cursor and selection handling


#### Txtbuf:currentPosition\(\)

Getter returning `line, cursor.col, cursor.row`\.

In that order, because we often need the first two and occasionally need the
third\.

```lua
function Txtbuf.currentPosition(txtbuf)
   local row, col = txtbuf.cursor:rowcol()
   return txtbuf[row], col, row
end
```


#### Txtbuf:setCursor\(rowOrTable, col\)

Set the `cursor`, ensuring that the value is not shared with the caller\.
Accepts either a cursor\-like table, or two arguments representing `row` and `col`\.
Either `row` or `col` may be `nil`, in which case the current value is retained\.
Also opens the row to which the cursor is being moved\.

Explicit new values must be in\-bounds\. If `col` is `nil`, we constrain the
value saved in the cursor to be within the length of the new row, but save the
unconstrained value in `txtbuf.desired_col` so we can "remember" the
horizontal position when moving between lines of differing lengths\.

```lua
local core_math = require "core/math"
local clamp, inbounds = assert(core_math.clamp), assert(core_math.inbounds)
local Point = require "anterm/point"

function Txtbuf.setCursor(txtbuf, rowOrTable, col)
   local row
   if type(rowOrTable) == "table" then
      row, col = rowOrTable.row, rowOrTable.col
   else
      row = rowOrTable
   end
   row = row or txtbuf.cursor.row
   assert(inbounds(row, 1, #txtbuf))
   txtbuf:openRow(row)
   if col then
      assert(inbounds(col, 1, #txtbuf[row] + 1))
      -- Explicit horizontal motion, forget any remembered horizontal position
      txtbuf.desired_col = nil
   else
      -- Remember where we were horizontally before clamping
      txtbuf.desired_col = txtbuf.desired_col or txtbuf.cursor.col
      col = clamp(txtbuf.desired_col, nil, #txtbuf[row] + 1)
   end
   txtbuf.cursor = Point(row, col)
   txtbuf.cursor_changed = true
end
```


#### Txtbuf:cursorIndex\(\)

Answers the index of the cursor in the string represented by the Txtbuf,
with newlines counted as a single slot/character\.

```lua
function Txtbuf.cursorIndex(txtbuf)
   local index = txtbuf.cursor.col
   for row = txtbuf.cursor.row - 1, 1, -1 do
      index = index + #txtbuf[row] + 1
   end
   return index
end
```


#### Txtbuf:beginSelection\(\)

Begins a selection operation by setting the `mark` equal to the `cursor`\.
Note that until the cursor is subsequently moved, this state is not a valid
selection and will be cleared as soon as someone inquires :hasSelection\(\)

```lua
function Txtbuf.beginSelection(txtbuf)
   txtbuf.mark = clone(txtbuf.cursor)
end
```


#### Txtbuf:clearSelection\(\)

Clears the current selection\. This again is considered a cursor change\.

```lua
function Txtbuf.clearSelection(txtbuf)
   if txtbuf:hasSelection() then
      txtbuf.cursor_changed = true
   end
   txtbuf.mark = nil
end
```


#### Txtbuf:hasSelection\(\)

Answers whether there is an active selection\. Note that a zero\-width selection
is only transiently valid\-\-it is necessary to start with, immediately after
a :beginSelection\(\), but for the purposes of this method the two must be
different\. If they are not, we actually clear the mark, since otherwise
further cursor moves **would** create a selection\.

```lua
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
```


#### Txtbuf:selectionStart\(\), Txtbuf:selectionEnd\(\)

Returns the left and right edge of the selection, respectively\-\-the earlier
or later of `cursor` and `mark`\. Used by operations that care only about what
is selected, not how it got that way\.

Returns two values, in `col`, `row` order for consistency with `currentPosition`\.

```lua
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
```


### Insertion


#### Txtbuf:openRow\(row\_num\)

Opens the row at index `row_num` for editing, breaking it into a grid of characters\.
Answers the newly\-opened line and index, or nil if the index is out of bounds\.

```lua

function Txtbuf.openRow(txtbuf, row_num)
   if row_num < 1 or row_num > #txtbuf then
      return nil
   end
   if type(txtbuf[row_num]) == "string" then
      txtbuf[row_num] = Codepoints(txtbuf[row_num])
   end
   return txtbuf[row_num], row_num
end

```


#### Txtbuf:nl\(\)

Splits the line at the current cursor position, effectively
inserting a newline\.

```lua
function Txtbuf.nl(txtbuf)
   line, cur_col, cur_row = txtbuf:currentPosition()
   -- split the line
   local first = slice(line, 1, cur_col - 1)
   local second = slice(line, cur_col)
   txtbuf[cur_row] = first
   insert(txtbuf, cur_row + 1, second)
   txtbuf:contentsChanged()
   txtbuf:setCursor(cur_row + 1, 1)
   return false
end
```


#### Txtbuf:insert\(frag\)

Inserts `frag` \(which must be exactly one codepoint\) at the current cursor
position\. Intended for when the user has pressed the corresponding key\-\-
performs automatic brace pairing\.

```lua
local inverse = assert(require "core:table" . inverse)
local _openers = { ["("] = ")",
                   ['"'] = '"',
                   ["'"] = "'",
                   ["{"] = "}",
                   ["["] = "]"}
local _closers = inverse(_openers)

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
   local line, cur_col = txtbuf:currentPosition()
   if _should_insert(line, cur_col, frag) then
      if _should_pair(line, cur_col, frag) then
         insert(line, cur_col, _openers[frag])
      end
      insert(line, cur_col, frag)
      txtbuf:contentsChanged()
   end
   txtbuf:setCursor(nil, cur_col + 1)
   return true
end
```


#### Txtbuf:paste\(frag\)

Pastes `frag` \(which may be many characters and may include newlines\)
at the current cursor position\. The only translation performed is
tab to three spaces\.

```lua
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
   txtbuf:contentsChanged()
end
```


### Deletion

Most deletion commands correspond to a cursor motion, deleting everything
between the current cursor position and that after the move\. All deletion
thus proceeds through :killSelection\(\)


#### Txtbuf:killSelection\(\)

Deletes the selected text, if any\. Returns whether anything was deleted
\(i\.e\. whether anything was initially selected\)\.

```lua
local deleterange = import("core/table", "deleterange")
function Txtbuf.killSelection(txtbuf)
   if not txtbuf:hasSelection() then
      return false
   end
   txtbuf:contentsChanged()
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
```


#### Txtbuf:killForward\(\), :killToBeginningOfLine\(\), etc\.

Other deletion commands are implemented as a select\-move\-delete sequence:

```lua
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

```

#### Txtbuf:killBackward\(disp\)

killBackward is slightly special, because we want to remove adjacent
paired braces if the opening brace is deleted\. We can still handle this
with a select\-move\-delete sequence, but need to inspect nearby chars first\.

```lua
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
```


### Cursor motions


#### Txtbuf:left\(disp\), Txtbuf:right\(disp\)

These methods shift a cursor left or right, handling line breaks internally\.

`disp` is a number of codepoints to shift\.

```lua
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
```


#### Txtbuf:up\(\), Txtbuf:down\(\)

Moves the cursor up or down a line, or to the beginning of the first line or
end of the last line if there is no line above/below\.

Returns whether it was able to move to a different line, i\.e\. false in the
case of moving to the beginning/end of the first/last line\.

```lua
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
```


#### Txtbuf:startOfLine\(\), Txtbuf:endOfLine\(\)

```lua
function Txtbuf.startOfLine(txtbuf)
   txtbuf:setCursor(nil, 1)
end

function Txtbuf.endOfLine(txtbuf)
   txtbuf:setCursor(nil, #txtbuf[txtbuf.cursor.row] + 1)
end

```

#### Txtbuf:startOfText\(\), Txtbuf:endOfText\(\)

Moves to the very beginning or end of the buffer\.

```lua
function Txtbuf.startOfText(txtbuf)
   txtbuf:setCursor(1, 1)
end

function Txtbuf.endOfText(txtbuf)
   txtbuf:setCursor(#txtbuf, #txtbuf[#txtbuf] + 1)
end
```


#### Txtbuf:scanFor\(pattern, reps, forward\)

Search left or right for a character matching `pattern`, after
encountering at least one character **not** matching `pattern`\. Matches the
position on the matching character when moving right, or one cell ahead of it
when moving left, "between" a non\-matching character
and a matching one\.

Returns move, the cursor delta, and the row delta\.


- \#parameters

   - pattern:  A pattern matching character\(s\) to stop at\. Generally either a
       single character or a single character class, e\.g\. %W

   - reps:     Number of times to repeat the motion

   - forward:  Boolean, true for forward search, false for backward\.

```lua
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
```


#### Txtbuf\[left|right\]ToBoundary\(pattern, reps\)

Finds the left or right delta, and moves the cursor if the pattern was found\.

```lua
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
```

#### Txtbuf:firstNonWhitespace\(\)

Moves to the first non\-whitespace character of the current line\. Return value
indicates whether such a character exists\. Does not move the cursor if the
line is empty or all whitespace\.

```lua
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
```

#### Txtbuf:leftWordAlpha\(reps\), Txtbuf:rightWordAlpha\(reps\), Txtbuf:leftWordWhitespace\(reps\), Txtbuf:rightWordWhitespace\(reps\)

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


### Other editing commands


#### Txtbuf:replaceChar\(frag\)

Replaces the character to the right of the cursor with the given codepoint\.

This is called `frag` as a reminder that, a\) it's variable width and b\) to
really nail displacement we need to be looking up displacements in some kind
of region\-defined lookup table\.


#### Txtbuf:transposeLetter\(\)

Transposes the letter at the cursor with the one before it\.

Readline has a small affordance where it will still transpose if the cursor is
at the end of a line, which this implementation respects\.

```lua
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
   txtbuf:contentsChanged()
   return true
end
```


### Txtbuf:shouldEvaluate\(\)

Answers true if the txtbuf should be evaluated when Return is pressed,
false if we should insert a newline\.

```lua
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
```


### Rendering \(Rainbuf protocol\)


#### Txtbuf:initComposition\(cols\)

```lua
function Txtbuf.initComposition(txtbuf, cols)
   txtbuf:super"initComposition"(cols)
   txtbuf.render_row = 1
end
```


#### Txtbuf:\_composeOneLine\(\)

```lua
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
         tokens[i] = txtbuf.active_suggestions:highlight(suggestion, txtbuf.cols, c)
      else
         tokens[i] = tok:toString(c)
      end
   end
   txtbuf.render_row = txtbuf.render_row + 1
   return concat(tokens)
end
```

### Txtbuf:tokens\(\[row\]\)

Breaks the contents of the Txtbuf, or a single row if `row` is supplied,
into tokens using the assigned lexer

```lua
function Txtbuf.tokens(txtbuf, row)
   if row then
      local cursor_col = txtbuf.cursor.row == row
         and txtbuf.cursor.col or 0
      return txtbuf.lex(cat(txtbuf[row]), cursor_col)
   else
      return txtbuf.lex(tostring(txtbuf), txtbuf:cursorIndex())
   end
end
```

### Txtbuf:suspend\(\), Txtbuf:resume\(\)

```lua
function Txtbuf.suspend(txtbuf)
   for i, v in ipairs(txtbuf) do
      txtbuf[i] = cat(v)
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
   -- Clone the lines as well as the Txtbuf itself
   local tb = clone(txtbuf, 2)
   return tb:resume()
end
```


### Txtbuf:\_init\(\), Txtbuf:replace\(str\)

```lua
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
   txtbuf:super"replace"(str)
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
   txtbuf:contentsChanged()
   txtbuf:endOfText()
   return txtbuf
end
```

```lua
local Txtbuf_class = setmetatable({}, Txtbuf)
Txtbuf.idEst = Txtbuf_class

return Txtbuf_class
```
# EditAgent

Agent responsible for editing text, primarily the line in the command zone,
but also premise titles and other things as needed\.

Text is stored as an array of lines, which start out as strings\. When the
cursor enters a line, it is "opened" into an array of codepoints\.

```lua
local meta = assert(require "core:cluster" . Meta)
local Agent = require "helm:agent/agent"
local EditAgent = meta(getmetatable(Agent))
```


#### imports

```lua
local Codepoints = require "singletons/codepoints"
local lines = import("core/string", "lines")
local clone, collect, slice, splice =
   import("core/table", "clone", "collect", "slice", "splice")

local concat, insert, remove = assert(table.concat),
                               assert(table.insert),
                               assert(table.remove)
```


### Instance fields


-  <array portion> :  An array of strings \(closed lines\), or arrays containing
    codepoints \(string fragments\) \(open lines\)\.


-  cursor :  A <Point> representing the cursor position:
   - row : Row containing the cursor\. Valid values are 1 to \#lines\.
   - col : Number of fragments to skip before an insertion\.
       Valid values are 1 to \#lines\[row\] \+ 1\.

   These fields shouldn't be written to, use `agent:setCursor()` which will
   check bounds\.  They may be retrieved, along with the line, with
   `agent:currentPosition()`\.


-  desired\_col : The column where the cursor "should" be, even if this is
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


-  lex :  A function accepting a string and returning an array of Tokens,
    which supports \`SuggestAgent\` and syntax highlighting in \`Txtbuf\`\.



-  cursor\_changed :   A flag indicating whether the cursor has changed since
    the flag was last reset\.

-  contents\_changed : Similar flag for whether the actual contents of the
    buffer have changed\.
    \#todo this is redundant with \.touched, but is cleared
    at a different time\. Maybe we can combine somehow?

The intention is that all of these fields are manipulated internally: the
codebase doesn't completely respect this, yet, but it should\.

This will let us expand, for instance, the definition of `cursor` to allow for
an array of cursors, in the event that there's more than one, without exposing
this elaboration to the rest of the system\.

The `EditAgent` is also a candidate for full replacement with the quipu data
structure, so the more we can encapsulate its region of responsiblity, the
cleaner that transition can be\.


#### Instance fields to be added


- disp :  Array of numbers, representing the furthest\-right column which
    may be reached by printing the corresponding row\. Not equivalent
    to \#lines\[n\] as one codepoint \!= one column\.


## Methods


### EditAgent:contentsChanged\(\)

Notification that the contents of the EditAgent have changed\. We additionally
set a flag for modeS to check after processing the current event\. \#todo this
should probably be replaced by queueing a message to modeS as well as to the
buffer\.

```lua
function EditAgent.contentsChanged(agent)
   Agent.contentsChanged(agent)
   agent.contents_changed = true
end
```


### EditAgent:setLexer\(lex\_fn\)

Set the lexer function\. Wrapped in a method because we also need to trigger a
repaint, though note that this does **not** fully qualify as a content change as
the actual text has **not** changed\.

```lua
function EditAgent.setLexer(agent, lex_fn)
   if agent.lex ~= lex_fn then
      agent.lex = lex_fn
      agent:bufferCommand("clearCaches")
   end
end
```


### Cursor and selection handling


#### EditAgent:currentPosition\(\)

Getter returning `line, cursor.col, cursor.row`\.

In that order, because we often need the first two and occasionally need the
third\.

```lua
function EditAgent.currentPosition(agent)
   local row, col = agent.cursor:rowcol()
   return agent[row], col, row
end
```


#### EditAgent:setCursor\(rowOrTable, col\)

Set the `cursor`, ensuring that the value is not shared with the caller\.
Accepts either a cursor\-like table, or two arguments representing `row` and `col`\.
Either `row` or `col` may be `nil`, in which case the current value is retained\.
Also opens the row to which the cursor is being moved\.

Explicit new values must be in\-bounds\. If `col` is `nil`, we constrain the
value saved in the cursor to be within the length of the new row, but save the
unconstrained value in `agent.desired_col` so we can "remember" the
horizontal position when moving between lines of differing lengths\.

```lua
local core_math = require "core/math"
local clamp, inbounds = assert(core_math.clamp), assert(core_math.inbounds)
local Point = require "anterm/point"

function EditAgent.setCursor(agent, rowOrTable, col)
   local row
   if type(rowOrTable) == "table" then
      row, col = rowOrTable.row, rowOrTable.col
   else
      row = rowOrTable
   end
   row = row or agent.cursor.row
   assert(inbounds(row, 1, #agent))
   agent:openRow(row)
   if col then
      assert(inbounds(col, 1, #agent[row] + 1))
      -- Explicit horizontal motion, forget any remembered horizontal position
      agent.desired_col = nil
   else
      -- Remember where we were horizontally before clamping
      agent.desired_col = agent.desired_col or agent.cursor.col
      col = clamp(agent.desired_col, nil, #agent[row] + 1)
   end
   agent.cursor = Point(row, col)
   agent.cursor_changed = true
end
```


#### EditAgent:cursorIndex\(\)

Answers the index of the cursor in the string represented by the EditAgent,
with newlines counted as a single slot/character\.

```lua
function EditAgent.cursorIndex(agent)
   local index = agent.cursor.col
   for row = agent.cursor.row - 1, 1, -1 do
      index = index + #agent[row] + 1
   end
   return index
end
```


#### EditAgent:beginSelection\(\)

Begins a selection operation by setting the `mark` equal to the `cursor`\.
Note that until the cursor is subsequently moved, this state is not a valid
selection and will be cleared as soon as someone inquires :hasSelection\(\)

```lua
function EditAgent.beginSelection(agent)
   agent.mark = clone(agent.cursor)
end
```


#### EditAgent:clearSelection\(\)

Clears the current selection\. This again is considered a cursor change\.

```lua
function EditAgent.clearSelection(agent)
   if agent:hasSelection() then
      agent.cursor_changed = true
   end
   agent.mark = nil
end
```


#### EditAgent:hasSelection\(\)

Answers whether there is an active selection\. Note that a zero\-width selection
is only transiently valid\-\-it is necessary to start with, immediately after
a :beginSelection\(\), but for the purposes of this method the two must be
different\. If they are not, we actually clear the mark, since otherwise
further cursor moves **would** create a selection\.

```lua
function EditAgent.hasSelection(agent)
   if not agent.mark then return false end
   if agent.mark.row == agent.cursor.row
      and agent.mark.col == agent.cursor.col then
      agent.mark = nil
      return false
   else
      return true
   end
end
```


#### EditAgent:selectionStart\(\), EditAgent:selectionEnd\(\)

Returns the left and right edge of the selection, respectively\-\-the earlier
or later of `cursor` and `mark`\. Used by operations that care only about what
is selected, not how it got that way\.

Returns two values, in `col`, `row` order for consistency with `currentPosition`\.

```lua
function EditAgent.selectionStart(agent)
   if not agent:hasSelection() then return nil end
   local c, m = agent.cursor, agent.mark
   if m.row < c.row or
      (m.row == c.row and m.col < c.col) then
      return m.col, m.row
   else
      return c.col, c.row
   end
end

function EditAgent.selectionEnd(agent)
   if not agent:hasSelection() then return nil end
   local c, m = agent.cursor, agent.mark
   if m.row > c.row or
      (m.row == c.row and m.col > c.col) then
      return m.col, m.row
   else
      return c.col, c.row
   end
end
```


### Insertion


#### EditAgent:openRow\(row\_num\)

Opens the row at index `row_num` for editing, breaking it into a grid of characters\.
Answers the newly\-opened line and index, or nil if the index is out of bounds\.

```lua

function EditAgent.openRow(agent, row_num)
   if row_num < 1 or row_num > #agent then
      return nil
   end
   if type(agent[row_num]) == "string" then
      agent[row_num] = Codepoints(agent[row_num])
   end
   return agent[row_num], row_num
end

```


#### EditAgent:nl\(\)

Splits the line at the current cursor position, effectively
inserting a newline\.

```lua
function EditAgent.nl(agent)
   line, cur_col, cur_row = agent:currentPosition()
   -- split the line
   local first = slice(line, 1, cur_col - 1)
   local second = slice(line, cur_col)
   agent[cur_row] = first
   insert(agent, cur_row + 1, second)
   agent:contentsChanged()
   agent:setCursor(cur_row + 1, 1)
end
```


#### EditAgent:tab\(\)

Respond to a press of the Tab key \(that was not handled by any other Agent\)\.
Translate to three spaces\.

```lua
function EditAgent.tab(agent)
   agent:paste("   ")
end
```

#### EditAgent:insert\(frag\)

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

function EditAgent.insert(agent, frag)
   local line, cur_col = agent:currentPosition()
   if _should_insert(line, cur_col, frag) then
      if _should_pair(line, cur_col, frag) then
         insert(line, cur_col, _openers[frag])
      end
      insert(line, cur_col, frag)
      agent:contentsChanged()
   end
   agent:setCursor(nil, cur_col + 1)
   return true
end
```


#### EditAgent:paste\(frag\)

Pastes `frag` \(which may be many characters and may include newlines\)
at the current cursor position\. The only translation performed is
tab to three spaces\.

```lua
function EditAgent.paste(agent, frag)
   frag = frag:gsub("\t", "   ")
   local frag_lines = collect(lines, frag)
   for i, frag_line in ipairs(frag_lines) do
      if i > 1 then agent:nl() end
      local codes = Codepoints(frag_line)
      local line, cur_col, cur_row = agent:currentPosition()
      splice(line, cur_col, codes)
      agent:setCursor(nil, cur_col + #codes)
   end
   agent:contentsChanged()
end
```


### Deletion

Most deletion commands correspond to a cursor motion, deleting everything
between the current cursor position and that after the move\. All deletion
thus proceeds through :killSelection\(\)


#### EditAgent:killSelection\(\)

Deletes the selected text, if any\. Returns whether anything was deletedi\.e\. whether anything was initially selected\)\.

\(
```lua
local deleterange = import("core/table", "deleterange")
function EditAgent.killSelection(agent)
   if not agent:hasSelection() then
      -- #todo communicate that there was nothing to do somehow,
      -- without falling through to the next command in the keymap
      return
   end
   agent:contentsChanged()
   local start_col, start_row = agent:selectionStart()
   local end_col, end_row = agent:selectionEnd()
   if start_row == end_row then
      -- Deletion within a line, just remove some chars
      deleterange(agent[start_row], start_col, end_col - 1)
   else
      -- Grab both lines--we're about to remove the end line
      local start_line, end_line = agent[start_row], agent[end_row]
      deleterange(agent, start_row + 1, end_row)
      -- Splice lines together
      for i = start_col, #start_line do
         start_line[i] = nil
      end
      for i = end_col, #end_line do
         insert(start_line, end_line[i])
      end
   end
   -- Cursor always ends up at the start of the formerly-selected area
   agent:setCursor(start_row, start_col)
   -- No selection any more
   agent:clearSelection()
end
```


#### EditAgent:killForward\(\), :killToBeginningOfLine\(\), etc\.

Other deletion commands are implemented as a select\-move\-delete sequence:

```lua
local function _delete_for_motion(motionName)
   return function(agent, ...)
      agent:beginSelection()
      agent[motionName](agent, ...)
      return agent:killSelection()
   end
end

for delete_name, motion_name in pairs({
   killForward = "right",
   killToEndOfLine = "endOfLine",
   killToBeginningOfLine = "startOfLine",
   killToEndOfWord = "rightWordAlpha",
   killToBeginningOfWord = "leftWordAlpha"
}) do
   EditAgent[delete_name] = _delete_for_motion(motion_name)
end

```


#### EditAgent:killBackward\(disp\)

killBackward is slightly special, because we want to remove adjacent
paired braces if the opening brace is deleted\. We can still handle this
with a select\-move\-delete sequence, but need to inspect nearby chars first\.

```lua
local function _is_paired(a, b)
   -- a or b might be out-of-bounds, and if a is not a brace and b is nil,
   -- we would incorrectly answer true, so check that both a and b are present
   return a and b and _openers[a] == b
end

function EditAgent.killBackward(agent, disp)
   disp = disp or 1
   local line, cur_col, cur_row = agent:currentPosition()
   -- Only need to check the character immediately to the left of the cursor
   -- since if we encounter paired braces later, we will delete the
   -- closing brace first anyway
   if _is_paired(line[cur_col - 1], line[cur_col]) then
      agent:right()
      disp = disp + 1
   end
   agent:beginSelection()
   agent:left(disp)
   agent:killSelection()
end
```


### Cursor motions


#### EditAgent:left\(disp\), EditAgent:right\(disp\)

These methods shift a cursor left or right, handling line breaks internally\.

`disp` is a number of codepoints to shift\.

```lua
function EditAgent.left(agent, disp)
   disp = disp or 1
   local line, new_col, new_row = agent:currentPosition()
   new_col = new_col - disp
   while new_col < 1 do
      line, new_row = agent:openRow(new_row - 1)
      if not new_row then
         agent:setCursor(nil, 1)
         return false
      end
      new_col = #line + 1 + new_col
   end
   agent:setCursor(new_row, new_col)
   return true
end

function EditAgent.right(agent, disp)
   disp = disp or 1
   local line, new_col, new_row = agent:currentPosition()
   new_col = new_col + disp
   while new_col > #line + 1 do
      _, new_row = agent:openRow(new_row + 1)
      if not new_row then
         agent:setCursor(nil, #line + 1)
         return false
      end
      new_col = new_col - #line - 1
      line = agent[new_row]
   end
   agent:setCursor(new_row, new_col)
   return true
end
```


#### EditAgent:up\(\), EditAgent:down\(\)

Moves the cursor up or down a line, or to the beginning of the first line or
end of the last line if there is no line above/below\.

Returns whether we were able to move the cursor, including the fallback case
of moving to the beginning/end of the first/last line\.

```lua
function EditAgent.up(agent)
   if agent:openRow(agent.cursor.row - 1) then
      agent:setCursor(agent.cursor.row - 1, nil)
      return true
   -- Move to beginning
   elseif agent.cursor.col > 1 then
      agent:setCursor(nil, 1)
      return true
   end
   -- Can't move at all
   return false
end

function EditAgent.down(agent)
   if agent:openRow(agent.cursor.row + 1) then
      agent:setCursor(agent.cursor.row + 1, nil)
      return true
   else
      local row_len = #agent[agent.cursor.row]
      -- Move to end
      if agent.cursor.col <= row_len then
         agent:setCursor(nil, row_len + 1)
         return true
      end
   end
   -- Can't move at all
   return false
end
```


#### EditAgent:startOfLine\(\), EditAgent:endOfLine\(\)

```lua
function EditAgent.startOfLine(agent)
   agent:setCursor(nil, 1)
end

function EditAgent.endOfLine(agent)
   agent:setCursor(nil, #agent[agent.cursor.row] + 1)
end
```


#### EditAgent:startOfText\(\), EditAgent:endOfText\(\)

Moves to the very beginning or end of the buffer\.

```lua
function EditAgent.startOfText(agent)
   agent:setCursor(1, 1)
end

function EditAgent.endOfText(agent)
   agent:openRow(#agent)
   agent:setCursor(#agent, #agent[#agent] + 1)
end
```


#### EditAgent:scanFor\(pattern, reps, forward\)

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

function EditAgent.scanFor(agent, pattern, reps, forward)
   local change = forward and 1 or -1
   reps = reps or 1
   local found_other_char, moved = false, false
   local line, cur_col, cur_row = agent:currentPosition()
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
         -- break out on agent boundaries
         if search_row == (forward and #agent or 1) then break end
         line, search_row = agent:openRow(search_row + change)
         search_pos = forward and 1 or #line + 1
      else
         search_pos = search_pos + change
      end
      moved = true
   end

   return moved, search_pos - cur_col, search_row - cur_row
end
```


#### EditAgent\[left|right\]ToBoundary\(pattern, reps\)

Finds the left or right delta, and moves the cursor if the pattern was found\.

```lua
function EditAgent.leftToBoundary(agent, pattern, reps)
   local line, cur_col, cur_row = agent:currentPosition()
   local moved, colΔ, rowΔ = agent:scanFor(pattern, reps, false)
   if moved then
      agent:setCursor(cur_row + rowΔ, cur_col + colΔ)
      return true
   else
      return false
   end
end

function EditAgent.rightToBoundary(agent, pattern, reps)
   local line, cur_col, cur_row = agent:currentPosition()
   local moved, colΔ, rowΔ = agent:scanFor(pattern, reps, true)
   if moved then
      agent:setCursor(cur_row + rowΔ, cur_col + colΔ)
      return true
   else
      return false
   end
end
```


#### EditAgent:firstNonWhitespace\(\)

Moves to the first non\-whitespace character of the current line\. Return value
indicates whether such a character exists\. Does not move the cursor if the
line is empty or all whitespace\.

```lua
function EditAgent.firstNonWhitespace(agent)
   local line = agent[agent.cursor.row]
   local new_col = 1
   while new_col <= #line do
      if match(line[new_col], '%S') then
         agent:setCursor(nil, new_col)
         return true
      end
      new_col = new_col + 1
   end
   return false
end
```


#### EditAgent:leftWordAlpha\(reps\), EditAgent:rightWordAlpha\(reps\), EditAgent:leftWordWhitespace\(reps\), EditAgent:rightWordWhitespace\(reps\)

```lua
function EditAgent.leftWordAlpha(agent, reps)
   return agent:leftToBoundary('%W', reps)
end

function EditAgent.rightWordAlpha(agent, reps)
   return agent:rightToBoundary('%W', reps)
end

function EditAgent.leftWordWhitespace(agent, reps)
   return agent:leftToBoundary('%s', reps)
end

function EditAgent.rightWordWhitespace(agent, reps)
   return agent:rightToBoundary('%s', reps)
end
```


### Other editing commands


#### EditAgent:replaceChar\(frag\)

Replaces the character to the right of the cursor with the given codepoint\.

This is called `frag` as a reminder that, a\) it's variable width and b\) to
really nail displacement we need to be looking up displacements in some kind
of region\-defined lookup table\.


#### EditAgent:replaceToken\(frag\)

Replaces the Token in which the cursor resides with the given fragment\.

```lua
function EditAgent.replaceToken(agent, frag)
   local cursor_token
   for _, token in ipairs(agent:tokens(agent.cursor.row)) do
      if token.cursor_offset then
         cursor_token = token
         break
      end
   end
   agent:right(cursor_token.total_disp - cursor_token.cursor_offset)
   agent:killBackward(cursor_token.total_disp)
   agent:paste(frag)
end
```


#### EditAgent:transposeLetter\(\)

Transposes the letter at the cursor with the one before it\.

Readline has a small affordance where it will still transpose if the cursor is
at the end of a line, which this implementation respects\.

```lua
function EditAgent.transposeLetter(agent)
   local line, cur_col, cur_row = agent:currentPosition()
   if cur_col == 1 then return false end
   if cur_col == 2 and #line == 1 then return false end
   local left, right = cur_col - 1, cur_col
   if cur_col == #line + 1 then
      left, right = left - 1, right - 1
   end
   local stash = line[right]
   line[right] = line[left]
   line[left] = stash
   agent:setCursor(nil, right + 1)
   agent:contentsChanged()
   return true
end
```


### EditAgent:shouldEvaluate\(\)

Answers true if the agent should be evaluated when Return is pressed,
false if we should insert a newline\.

```lua
function EditAgent.shouldEvaluate(agent)
   -- Most agents are one line, so we always evaluate from
   -- a one-liner, regardless of cursor location.
   local linum = #agent
   if linum == 1 then
      return true
   end
   local _, cur_col, cur_row = agent:currentPosition()
   -- Evaluate if we are at the end of the first or last line (the default
   -- positions after scrolling up or down in the history)
   if (cur_row == 1 or cur_row == linum) and cur_col > #agent[cur_row] then
      return true
   end
end
```


### EditAgent:update\(str\)

Although we are constructed from a string, the actual value we store is an
array of lines\.

\#todo
best name for it?

```lua
function EditAgent.update(agent, str)
   str = str or ""
   local i = 1
   for line in lines(str) do
      agent[i] = line
      i = i + 1
   end
   for j = i, #agent do
      agent[j] = nil
   end
   agent:contentsChanged()
   agent:endOfText()
   return agent
end
```


### EditAgent:clear\(\)

\#todo

```lua
function EditAgent.clear(agent)
   agent:update("")
end
```


### EditAgent:contents\(\)

Returns the contents of the agent as a single \(potentially multiline\) string\.

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

function EditAgent.contents(agent)
   local closed_lines = {}
   for k, v in ipairs(agent) do
      closed_lines[k] = cat(v)
   end
   return concat(closed_lines, "\n")
end
```


### EditAgent:isEmpty\(\)

Some events are processed specially when the command zone is empty, so we
expose this query separately from `:contents()`\.

```lua
function EditAgent.isEmpty(agent)
   return #agent == 1 and #agent[1] == 0
end
```


### Rendering\-related queries


#### EditAgent:continuationLines\(\)

The number of continuation lines \(lines past the first\)\. Simple enough, but
used in a couple places\.

```lua
function EditAgent.continuationLines(agent)
   return #agent - 1
end
```


#### EditAgent:tokens\(\[row\]\)

Breaks the contents of the agent, or a single row if `row` is supplied,
into tokens using the assigned lexer\.

```lua
function EditAgent.tokens(agent, row)
   if row then
      local cursor_col = agent.cursor.row == row
         and agent.cursor.col or 0
      return agent.lex(cat(agent[row]), cursor_col)
   else
      return agent.lex(agent:contents(), agent:cursorIndex())
   end
end
```


#### EditAgent:bufferValue\(\)

The buffer need not concern itself with which lines are "open"\.

```lua
function EditAgent.bufferValue(agent)
   local answer = {}
   for i, line in ipairs(agent) do
      answer[i] = cat(line)
   end
   return answer
end
```


#### EditAgent:windowConfiguration\(\)

We expose the cursor position and some functions related to lexing, which the
buffer uses in syntax highlighting\.

```lua
function EditAgent.windowConfiguration(agent)
   return agent.mergeWindowConfig(Agent.windowConfiguration(), {
      field = { cursor = true },
      closure = { cursorIndex = true,
                  tokens = true }
   })
end
```


### Input\-event handling and keymaps


#### EditAgent:selfInsert\(evt\)

Analogous to Readline's `self-insert` or emacs' `self-insert-command`\. Just
retrieve the actual character from the event and pass it to `insert`\.

```lua
function EditAgent.selfInsert(agent, evt)
   return agent:insert(evt.key)
end
```


#### EditAgent:evtPaste\(evt\)

Need to extract the pasted text from the event\.

```lua
function EditAgent.evtPaste(agent, evt)
   agent:paste(evt.text)
end
```


#### Basic editing commands keymap

The basic editing commands that are applicable no matter what we're editing\.

```lua
EditAgent.keymap_basic_editing = {
   -- Motions
   UP              = "up",
   DOWN            = "down",
   LEFT            = "left",
   RIGHT           = "right",
   ["M-LEFT"]      = "leftWordAlpha",
   ["M-b"]         = "leftWordAlpha",
   ["M-RIGHT"]     = "rightWordAlpha",
   ["M-w"]         = "rightWordAlpha",
   HOME            = "startOfLine",
   ["C-a"]         = "startOfLine",
   END             = "endOfLine",
   ["C-e"]         = "endOfLine",
   -- Kills
   BACKSPACE       = "killBackward",
   DELETE          = "killForward",
   ["M-BACKSPACE"] = "killToBeginningOfWord",
   ["M-DELETE"]    = "killToEndOfWord",
   ["M-d"]         = "killToEndOfWord",
   ["C-k"]         = "killToEndOfLine",
   ["C-u"]         = "killToBeginningOfLine",
   -- Misc editing commands
   ["C-t"]         = "transposeLetter",
   -- Insertion commands
   ["[CHARACTER]"] = { method = "selfInsert", n = 1 },
   TAB             = "tab",
   RETURN          = "nl",
   PASTE           = { method = "evtPaste", n = 1 }
}
```


#### Readline\-style navigation

Provides equivalent commands for diehard Emacsians\.

In case RMS ever takes bridge for a spin\.\.\.

```lua
EditAgent.keymap_readline_nav = {
   ["C-b"] = "left",
   ["C-f"] = "right",
   ["C-n"] = "down",
   ["C-p"] = "up"
}
```


### EditAgent:\_init\(\)

```lua
function EditAgent._init(agent)
   Agent._init(agent)
   agent[1] = ""
   agent:setCursor(1, 1)
   agent.contents_changed = false
   agent.cursor_changed = false
end
```


```lua
local constructor = assert(require "core:cluster" . constructor)
return constructor(EditAgent)
```

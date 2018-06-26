# Txtbuf


The ``txtbuf`` class buffers a single line of text.


To make editing practical, we model the line as an array of codepoints when
active, and a simple string otherwise.


``txtbuf`` are promoted to ``txtbuf`` if editing needs to span multiple lines.


## Instance fields


Instance fields for a txtbuf may be read by other code, but should be written
internally.


- line   :  An array of string fragments


- cursor :  An uint representing the number of bytes to be skipped over
            before executing ``insert()``.  Not 1-1 the same as the column
            index of the tty cursor.


            cursor is moved by txtbuf, ensuring we stay on codepoint
            boundaries.


#### imports

```lua
local sub, byte = assert(string.sub), assert(string.byte)
local gsub = assert(string.gsub)
assert(meta, "txtbuf requires meta")
```
```lua
local Txtbuf = meta {}
```
```lua
local concat = table.concat

function Txtbuf.__tostring(txtbuf)
   if type(txtbuf.lines) == "table" then
      return concat(txtbuf.lines)
   else
      return txtbuf.lines
   end
end
```
## Txtbuf.insert(txtbuf, frag)

``insert`` takes a fragment and carefully places it at the cursor point.


A ``frag`` is any kind of string that we won't want to break into pieces.


At first that means pasting long strings will cause syntax highlighting to
fall over. Harmlessly.  Once lexing is working we can trip an interrupt on
long input.


### join(token, frag)

Decides when to emit a new token.

```lua
local function join(token, frag)
   if sub(token, -1) == " " and sub(frag, 1,1) ~= " " then
      return token, frag
   else
      return token .. frag, nil
   end
end

local t_insert, splice = assert(table.insert), assert(table.splice)
local utf8, codepoints = string.utf8, string.codepoints

function Txtbuf.insert(txtbuf, frag)
   local line = txtbuf.lines
   if type(line) == "string" then
      line = codepoints(line)
      txtbuf.lines = line
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

local remove = table.remove

function Txtbuf.d_back(txtbuf)
   remove(txtbuf.lines, txtbuf.cursor - 1)
   txtbuf.cursor = txtbuf.cursor > 1 and txtbuf.cursor - 1 or 1
end


function Txtbuf.d_fwd(txtbuf)
   remove(txtbuf.lines, txtbuf.cursor)
end

function Txtbuf.left(txtbuf, disp)
   local disp = disp or 1
   if txtbuf.cursor - disp >= 1 then
      txtbuf.cursor = txtbuf.cursor - disp
      return txtbuf.cursor
   else
      txtbuf.cursor = 1
      return txtbuf.cursor
   end
end

function Txtbuf.right(txtbuf, disp)
   disp = disp or 1
   if txtbuf.cursor + disp <= #txtbuf.lines + 1 then
      txtbuf.cursor = txtbuf.cursor + disp
   else
      txtbuf.cursor = #txtbuf.lines + 1
   end
   return txtbuf.cursor
end
```
```lua
local cl = assert(table.clone, "table.clone must be provided")

function Txtbuf.suspend(txtbuf)
   txtbuf.lines = tostring(txtbuf)
   return txtbuf
end

function Txtbuf.resume(txtbuf)
   txtbuf.lines = codepoints(txtbuf.lines)
   txtbuf.cursor = #txtbuf.lines + 1
   return txtbuf
end
```
```lua
function Txtbuf.clone(txtbuf)
   local lb = cl(txtbuf)
   if type(lb.lines) == "table" then
      lb.lines = cl(lb.lines)
   elseif type(lb.lines) == "string" then
      lb:resume()
   end
   return lb
end
```
```lua
local function new(line)
   local txtbuf = meta(Txtbuf)
   txtbuf.cursor = line and #line or 1
   txtbuf.lines  = line or {}
   return txtbuf
end
```
```lua
return new
```

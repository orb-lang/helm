# Token

This represents a logical chunk of text generated as part of the repr process.
It includes metadata to assist with wrapping, coloration, and (eventually)
mouse handling.


An example token looks like:

```lua-example
{
   "f", "o", "o", "\\n",
   color = c.string,
   disps = { 1, 1, 1, 2 },
   total_disp = 5,
   escapes = { ["\\n"] = true },
   event = {"array", "map", "sep", "end", "repr_line"} -- One of those, or nil
}
```
## Interface

### Instance fields

-  <number> : The codepoints of the string this token represents
-  disps    : Array of the number of cells occupied by the corresponding
              codepoint string. There is no handling of Unicode widths at
              this point, but this may still be >1 in the case of an escaped
              nonprinting character, e.g. ``\t``, ``\x1b``.
-  color    : A color value to use for the entire token.
-  err      : A table with information about any errors encountered
              interpreting the original string as Unicode
-  is_string: Does this token represent a string; thus, is it acceptable to
              wrap it in the middle.

## Dependencies

```lua

local byte, codepoints, find, format = assert(string.byte),
                                       assert(string.codepoints),
                                       assert(string.find),
                                       assert(string.format)
local concat, insert, remove = assert(table.concat),
                               assert(table.insert),
                               assert(table.remove)

```
## Methods

```lua

local Token = meta {}
local new

```
### Token:toString(c)

Produces a string that should be output when displaying the Token,
including coloring sequences. Requires the color table in order to
colorize escapes and errors.

```lua

function Token.toString(token, c)
   local output = {}
   for i, frag in ipairs(token) do
      if token.escapes[frag] then
         frag = c.stresc .. frag .. token.color
      elseif token.err and token.err[i] then
         frag = c.alert .. frag .. token.color
      end
      output[i] = frag
   end
   return token.color(concat(output))
end

```
### Token:split(max_disp)

Splits a token such that the first part occupies no more than ``max_disp`` cells.
Returns two tokens.

```lua

function Token.split(token, max_disp)
   local disp_so_far = 0
   local split_index
   for i, disp in ipairs(token.disps) do
      if disp_so_far + disp > max_disp then
         split_index = i - 1
         break
      end
      disp_so_far = disp_so_far + disp
   end
   local first, rest = new(nil, token.color, token.event), new(nil, token.color, token.event)
   first.escapes = token.escapes
   rest.escapes = token.escapes
   for i = 1, #token do
      local target = i <= split_index and first or rest
      target:insert(token[i], token.disps[i], token.err and token.err[i])
   end
   return first, rest
end

```
### Token:insert([pos,] frag[, disp[, err]])

As ``table.insert``, but keeps ``disps`` and ``total_disp`` up to date.
Accepts the displacement of the fragment as a second (or third) argument.
Also accepts error information for the fragment as an optional third
(or fourth) argument.

```lua

function Token.insert(token, pos, frag, disp, err)
   if type(pos) ~= "number" then
      err = disp
      disp = frag
      frag = pos
      pos = #token + 1
   end
   -- Assume one cell if disp is not specified.
   -- Cannot use #frag because of Unicode--might be two bytes but one cell.
   disp = disp or 1
   insert(token, pos, frag)
   insert(token.disps, pos, disp)
   token.total_disp = token.total_disp + disp
   -- Create the error array if needed, and/or shift it if it exists (even if
   -- this fragment is not in error) to keep indices aligned
   if token.err or err then
      token.err = token.err or {}
      insert(token.err, pos, err)
   end
end

```
### Token:remove([pos])

As ``table.remove``, but keeps ``disps`` and ``total_disp`` up to date.
Answers the removed value, its displacement, and any associated error.

```lua

function Token.remove(token, pos)
   local removed = remove(token, pos)
   local rem_disp = remove(token.disps, pos)
   token.total_disp = token.total_disp - rem_disp
   local err = token.err and remove(token.err, pos)
   return removed, rem_disp, err
end

```
### new(str, color[, event[, is_string]])

Creates a ``Token`` from the given string, color value, and optional event name.


If ``is_string`` is truthy, performs some additional steps applicable
only to strings:


-  Converts nonprinting characters and quotation marks to their escaped forms,
   with the ``escapes`` property indicating which characters this has been done
   to.
-  Wraps the string in (un-escaped) quotation marks if it consists entirely of
   space characters (or is empty).


If ``str`` is nil, returns a blank ``Token``.

```lua

local escapes_map = {
   ['"'] = '\\"',
   ["'"] = "\\'",
   ["\a"] = "\\a",
   ["\b"] = "\\b",
   ["\f"] = "\\f",
   ["\n"] = "\\n",
   ["\r"] = "\\r",
   ["\t"] = "\\t",
   ["\v"] = "\\v"
}

new = function(str, color, event, is_string)
   local token = meta(Token)
   token.color = color
   token.event = event
   token.is_string = is_string
   token.disps = {}
   token.escapes = {}
   token.total_disp = 0
   if not str then
      return token
   end
   local codes = codepoints(str)
   token.err = codes.err
   for i, frag in ipairs(codes) do
      local disp
      if is_string and (escapes_map[frag] or find(frag, "%c")) then
         frag = escapes_map[frag] or format("\\x%x", byte(frag))
         -- In the case of an escape, we know all of the characters involved
         -- are one-byte, and each occupy one cell
         disp = #frag
         token.escapes[frag] = true
      else
         -- For now, assume that all codepoints occupy one cell.
         -- This is wrong, but *usually* does the right thing, and
         -- handling Unicode properly is hard.
         disp = 1
      end
      token:insert(frag, disp)
   end
   if is_string and find(str, '^ *$') then
      token:insert(1, '"')
      token:insert('"')
   end
   return token
end

Token.idEst = new

return new
```

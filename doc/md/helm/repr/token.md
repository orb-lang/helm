# Token

This represents a logical chunk of text generated as part of the repr process.
It includes metadata to assist with wrapping, coloration, and (eventually)
mouse handling.

## Interface

### Instance fields

-  str        : The original string this token was created from.
                NB If ``codepoints`` exists, this does not take into account
                any modifications made by insert(), remove(), or split().
-  start      : The index within ``str`` or ``codepoints`` at which this token
                starts. Used when splitting to avoid copying the contents
                after the split point (which could be arbitrarily large).
-  color      : A color value to use for the entire token.
-  event      : A string indicating that this token has a special meaning, like
                the beginning or end of an indented block, or a separator.
-  wrappable  : If true, it is acceptable to wrap this token by breaking it
                in the middle. If false, it should be moved entirely to the
                next line if it does not fit.
                Also controls whether or not the string will be broken into
                codepoints.


The following fields will be present only if ``wrappable`` is true:
-  codepoints : The codepoints of the string, if we needed to break it down.
-  disps      : Array of the number of cells occupied by the corresponding
                codepoint string. There is no handling of Unicode widths at
                this point, but this may still be >1 in the case of an escaped
                nonprinting character, e.g. ``\t``, ``\x1b``.
-  err        : A table with information about any errors encountered
                interpreting the original string as Unicode.

### Examples

Wrappable:

```lua-example
{
   str = "foo\n",
   codepoints = { "f", "o", "o", "\\n" },
   color = c.string,
   disps = { 1, 1, 1, 2 },
   wrappable = true,
   total_disp = 5,
   escapes = { ["\\n"] = true }
}
```

Non-wrappable:

```lua-example
{
   str = ", ",
   color = c.base,
   total_disp = 2,
   event = "sep"
}
```
## Dependencies

```lua

local Codepoints = require "singletons/codepoints"
local utf8 = require "lua-utf8"
local utf8_len, utf8_sub = utf8.len, utf8.sub
local concat, insert, remove = assert(table.concat),
                               assert(table.insert),
                               assert(table.remove)
local meta = require "core/meta" . meta
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
   if not token.wrappable then
      return token.color(utf8_sub(token.str, token.start))
   end
   local output = {}
   for i = token.start, #token.codepoints do
      local frag = token.codepoints[i]
      if token.escapes[frag] then
         frag = c.stresc .. frag .. token.color
      elseif token.err and token.err[i] then
         frag = c.alert .. frag .. token.color
      end
      insert(output, frag)
   end
   return token.color(concat(output))
end

```
### Token.toStringBW()

Produces a string with no coloring sequences, regardless of the value of
token.color. Mostly useful for debugging.

```lua

function Token.toStringBW(token)
   if token.wrappable then
      return concat(token.codepoints, "", token.start)
   else
      return utf8_sub(token.str, token.start)
   end
end

```
### Token:split(max_disp)

Splits a token such that the first part occupies no more than ``max_disp`` cells.
Modifies the receiver to start later in the underlying string, without actually
modifying said string, in order to avoid copying massive amounts of data.
Returns only the newly-created token, the first half of the split.

```lua

function Token.split(token, max_disp)
   local first
   local cfg = { event = token.event,
                 wrappable = token.wrappable,
                 wrapped = token.wrapped }
   if token.wrappable then
      cfg.escapes = token.escapes
      first = new(nil, token.color, cfg)
      for i = token.start, #token.codepoints do
         if first.total_disp + token.disps[i] > max_disp then
            token.start = i
            token.total_disp = token.total_disp - first.total_disp
            break
         end
         first:insert(token.codepoints[i], token.disps[i], token.err and token.err[i])
      end
   else
      first = new(utf8_sub(token.str, token.start, token.start + max_disp - 1), token.color, cfg)
      token.start = token.start + max_disp + 1
      token.total_disp = token.total_disp - max_disp
   end
   return first
end

```
### Token:insert([pos,] frag[, disp[, err]])

As ``table.insert``, but keeps ``disps`` and ``total_disp`` up to date.
Accepts the displacement of the fragment as a second (or third) argument.
Also accepts error information for the fragment as an optional third
(or fourth) argument.


For now, fails if this token is offset from the start of the underlying string.

```lua

function Token.insert(token, pos, frag, disp, err)
   assert(token.start == 1, "Cannot insert into a token with a start offset")
   if type(pos) ~= "number" then
      err = disp
      disp = frag
      frag = pos
      -- If we have a codepoints array, our total_disp might exceed its length
      -- because of escapes. If not, total_disp is assumed equal to the
      -- number of codepoints in the string
      pos = (token.codepoints and #token.codepoints or token.total_disp) + 1
   end
   -- Assume one cell if disp is not specified.
   -- Cannot use #frag because of Unicode--might be two bytes but one cell.
   disp = disp or 1
   if token.wrappable then
      insert(token.codepoints, pos, frag)
      insert(token.disps, pos, disp)
      -- Create the error array if needed, and/or shift it if it exists (even
      -- if this fragment is not in error) to keep indices aligned
      if token.err or err then
         token.err = token.err or {}
         insert(token.err, pos, err)
      end
   else
      token.str = utf8_sub(token.str, 1, pos - 1) .. frag .. utf8_sub(token.str, pos)
   end
   token.total_disp = token.total_disp + disp
end

```
### Token:remove([pos])

As ``table.remove``, but keeps ``disps`` and ``total_disp`` up to date.
Answers the removed value, its displacement, and any associated error.


For now, fails if this token is offset from the start of the underlying string.

```lua

function Token.remove(token, pos)
   assert(token.start == 1, "Cannot remove from a token with a start offset")
   local removed, rem_disp, err
   if token.wrappable then
      removed = remove(token.codepoints, pos)
      rem_disp = remove(token.disps, pos)
      err = token.err and remove(token.err, pos)
   else
      pos = pos or token.total_disp
      removed = utf8_sub(token.str, pos, pos)
      rem_disp = 1
      token.str = utf8_sub(token.str, 1, pos - 1) .. utf8_sub(token.str, pos + 1)
   end
   token.total_disp = token.total_disp - rem_disp
   return removed, rem_disp, err
end

```
### Token:removeTrailingSpaces()

Removes any trailing space characters from the token. Primarily used for
separators at the end of a line, to avoid bumping them to the next line
when in fact they fit perfectly.


This does not seem relevant to wrappable tokens--could be implemented later
if needed.

```lua

local string_sub = assert(string.sub)

function Token.removeTrailingSpaces(token)
   assert(not token.wrappable, "removeTrailingSpaces not implemented \
      for wrappable tokens")
   assert(token.start == 1, "removeTrailingSpaces not implemented \
      for tokens with a start offset")
   -- Note that we can ignore Unicode here, as we only care about spaces
   local last_non_space = -1
   while string_sub(token.str, last_non_space, last_non_space) == " " do
      last_non_space = last_non_space - 1
   end
   token.str = string_sub(token.str, 1, last_non_space)
   token.total_disp = token.total_disp + last_non_space + 1
end

```
### new(str, color[, cfg])

Creates a ``Token`` from the given string, color value, and optional table of
configuration options, which will be copied directly onto the token. Relevant
options include:
-  event: A string indicating that this token is special in some way--
   a separator, the beginning or end of an indented section, a line from
   a __repr function, etc.
-  wrappable: Should this token be subject to wrapping in the middle, or
   should it be moved entirely to the next line if it doesn't fit?
   Also triggers a number of other bits of behavior--see below.
-  total_disp: If str contains zero-width sequences (e.g. color escapes),
   calling code should indicate the correct total displacement of the string.
   Note that this does not mix well with ``wrappable`` and ``:split()``, which
   need to know the displacement of each codepoint. Re-parsing color escapes
   is a possible future enhancement.


Extra ``wrappable`` behavior:
-  Breaks the string up with ``codepoints()`` and records a displacement value
   for each codepoint.
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
   ["\\"] = "\\\\",
   ["\a"] = "\\a",
   ["\b"] = "\\b",
   ["\f"] = "\\f",
   ["\n"] = "\\n",
   ["\r"] = "\\r",
   ["\t"] = "\\t",
   ["\v"] = "\\v"
}

local byte, find, format = assert(string.byte),
                           assert(string.find),
                           assert(string.format)

new = function(str, color, cfg)
   local token = meta(Token)
   token.str = str
   token.start = 1
   token.color = color
   cfg = cfg or {}
   if cfg.wrappable then
      token.codepoints = Codepoints(str or "")
      token.err = token.codepoints.err
      token.disps = {}
      token.escapes = {}
      token.total_disp = 0
      for i, frag in ipairs(token.codepoints) do
         -- For now, start by assuming that all codepoints occupy one cell.
         -- This is wrong, but *usually* does the right thing, and
         -- handling Unicode properly is hard.
         local disp = 1
         if escapes_map[frag] or find(frag, "%c") then
            frag = escapes_map[frag] or format("\\x%02x", byte(frag))
            token.codepoints[i] = frag
            -- In the case of an escape, we know all of the characters involved
            -- are one-byte, and each occupy one cell
            disp = #frag
            token.escapes[frag] = true
         end
         token.disps[i] = disp
         token.total_disp = token.total_disp + disp
      end
      -- Note that we don't quote if str was nil, only if it was an actual
      -- empty string. nil is used to create a blank token into which chars
      -- will later be inserted (see :split()).
      if str and find(str, '^ *$') then
         -- Need to assign this over now so :insert() behaves properly
         token.wrappable = true
         token:insert(1, '"')
         token:insert('"')
      end
   else -- not cfg.wrappable
      token.total_disp = utf8_len(str)
   end
   for k, v in pairs(cfg) do
      token[k] = v
   end
   return token
end

Token.idEst = new

return new
```

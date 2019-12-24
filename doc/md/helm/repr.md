# Repr


``repr`` is our general-purpose pretty-printer.


This is undergoing a huge refactor to make it iterable, so it yields one
line at a time and won't get hung up on enormous tables.


Currently we yield most things, and are working our way toward providing an
iterator that itself returns one line at a time until it reaches the end of
the repr.


## imports

```lua
local C = require "singletons/color"
local Composer = require "helm/repr/composer"
local tabulate = require "helm/repr/tabulate"

local concat = assert(table.concat)
```
## setup

```lua

local repr = {}

```
### repr.lineGen(tab, disp_width), repr.lineGenBW(tab, disp_width)

Uses ``Composer`` and ``tabulate`` to produce an iterator of lines, displaying
the contents of ``tab``.

```lua

function repr.lineGen(tab, disp_width, color)
   color = color or C.color
   local generator = Composer(tabulate)
   return generator(tab, disp_width, color)
end

function repr.lineGenBW(tab, disp_width)
   return repr.lineGen(tab, disp_width, C.no_color)
end

```
### repr.ts(val[, disp_width[, color]])

Returns a representation of the value using the supplied color table,
defaulting to black-and-white.


Intended as a drop-in replacement for ``tostring()``, which unpacks tables and
provides names, presuming that ``anti_G`` has been populated.

```lua
function repr.ts(val, disp_width, color)
   local phrase = {}
   for line in repr.lineGen(val, disp_width, color or C.no_color) do
      phrase[#phrase + 1] = line
   end
   return concat(phrase, "\n")
end
```
### repr.ts_color(val, [disp_width, [color]])

A ``tostring`` which uses ANSI colors.  Optional arguments are the allowed
width of lines, and a color table.

```lua
function repr.ts_color(val, disp_width, color)
   return repr.ts(val, disp_width, color or C.color)
end
```
```lua
return repr
```

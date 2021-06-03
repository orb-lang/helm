# Sessionbuf

This is a type of `Rainbuf` specialized to display and edit a `Session`\.


## Instance fields


-  session:        The Session object we are displaying and editing\.

-  txtbufs:        Array of `Txtbuf`s for each line of the session\.

-  resbuf:         `Resbuf` for displaying the results of the selected line\.

-  selected\_index: The index of the line that is selected for editing

```lua
local Rainbuf = require "helm:buf/rainbuf"
local Resbuf  = require "helm:buf/resbuf"
local Txtbuf  = require "helm:buf/txtbuf"

local Sessionbuf = Rainbuf:inherit()
```


## Constants

```lua
-- The (maximum) number of rows we will use for the "line" (command)
-- (in case it is many lines long)
Sessionbuf.ROWS_PER_LINE = 4
-- The (maximum) number of rows we will use for the result of the selected line
Sessionbuf.ROWS_PER_RESULT = 7
```


## Methods


### Sessionbuf:contentCols\(\)

We have left and right borders, which immediately take off two columns of
width\. Padding matters too, but only to our sub\-buffers, so we can't account
for it here\.

```lua
function Sessionbuf.contentCols(buf)
   return buf:super"contentCols"() - 2
end
```


### Sessionbuf:setExtent\(rows, cols\)

Pass through extent changes to our sub\-buffers as needed\.

```lua
function Sessionbuf.setExtent(buf, rows, cols)
   buf:super"setExtent"(rows, cols)
   -- Account for additional padding
   buf.resbuf:setExtent(buf.ROWS_PER_RESULT, buf:contentCols() - 2)
   for _, txtbuf in ipairs(buf.txtbufs) do
      -- As above, but additionally three cells for the icon and space after it
      txtbuf:setExtent(buf.ROWS_PER_LINE, buf:contentCols() - 5)
   end
end
```


### Sessionbuf:checkTouched\(\)

Changes to our sub\-buffers \(e\.g\. from scrolling\) also count as touches\. We
don't early\-out once we know we're touched because we must still check and
clear everyone\.

```lua
function Sessionbuf.checkTouched(buf)
   if buf.resbuf:checkTouched() then
      buf:beTouched()
   end
   for _, txtbuf in ipairs(buf.txtbufs) do
      if txtbuf:checkTouched() then
         buf:beTouched()
      end
   end
   return buf:super"checkTouched"()
end
```


### Selection, scrolling, etc


#### Sessionbuf:selectIndex\(index\)

Select the line at `index` in the session for possible editing\.

```lua
local clamp = assert(require "core:math" . clamp)
function Sessionbuf.selectIndex(buf, index)
   index = #buf.value == 0
      and 0
      or clamp(index, 1, #buf.value)
   if index ~= buf.selected_index then
      buf.selected_index = index
      local premise = buf:selectedPremise()
      local result
      if premise then
         -- #todo re-evaluate sessions on -s startup, and display an
         -- indication of whether there are changes (and eventually a diff)
         -- rather than just the newest available result
         result = premise.new_result or premise.old_result
      end
      buf.resbuf:replace(result)
      buf.resbuf:scrollTo(0)
      return true
   end
   return false
end
```


#### Sessionbuf:selectNextWrap\(\), :selectPreviousWrap\(\)

Selects the next/previous premise, wrapping around to the beginning/end
if we're at the end/beginning, respectively\.

```lua
function Sessionbuf.selectNextWrap(buf)
   local new_idx = buf.selected_index < #buf.value
      and buf.selected_index + 1
      or 1
   return buf:selectIndex(new_idx)
end
function Sessionbuf.selectPreviousWrap(buf)
   local new_idx = buf.selected_index > 1
      and buf.selected_index - 1
      or #buf.value
   return buf:selectIndex(new_idx)
end
```


#### Sessionbuf:rowsForSelectedResult\(\)

Returns the number of lines needed to display the result of the
selected premise\. This will never be greater than ROWS\_PER\_RESULT\.
The Sessionbuf must have had :initComposition\(\) already called\.

```lua
function Sessionbuf.rowsForSelectedResult(buf)
   buf.resbuf:composeUpTo(buf.ROWS_PER_RESULT)
   return clamp(#buf.resbuf.lines, 0, buf.ROWS_PER_RESULT)
end
```


#### Sessionbuf:positionOf\(index\)

Returns the line number at which display of the `index`th premise begins\.

```lua
local gsub = assert(string.gsub)
function Sessionbuf.positionOf(buf, index)
   local position = 1
   for i = 1, index - 1 do
      local num_lines = select(2, gsub(buf.value[i].line, '\n', '\n')) + 1
      num_lines = clamp(num_lines, 1, buf.ROWS_PER_LINE)
      position = position + num_lines + 1
      if i == buf.selected_index then
         position = position + buf:rowsForSelectedResult() + 1
      end
   end
   return position
end

function Sessionbuf.positionOfSelected(buf)
   return buf:positionOf(buf.selected_index)
end
```


#### Sessionbuf:scrollResultsDown\(\), :scrollResultsUp\(\)

Scroll within the results area for the currently\-selected line\.

```lua
function Sessionbuf.scrollResultsDown(buf)
   return buf.resbuf:scrollDown()
end

function Sessionbuf.scrollResultsUp(buf)
   return buf.resbuf:scrollUp()
end
```


#### Sessionbuf:selectedPremise\(\)

```lua
function Sessionbuf.selectedPremise(buf)
   return buf.value[buf.selected_index]
end
```


### Editing


#### Sessionbuf:\[reverse\]toggleSelectedState\(\)

Toggles the state of the selected line, cycling through "accept", "reject",
"ignore", "skip"\.

```lua
local status_cycle_map = {
   ignore = "accept",
   accept = "reject",
   reject = "skip",
   skip   = "ignore"
}

function Sessionbuf.toggleSelectedState(buf)
   local premise = buf:selectedPremise()
   premise.status = status_cycle_map[premise.status]
   buf:beTouched()
   return true
end

local inverse = assert(require "core:table" . inverse)
local status_reverse_map = inverse(status_cycle_map)

function Sessionbuf.reverseToggleSelectedState(buf)
   local premise = buf:selectedPremise()
   premise.status = status_reverse_map[premise.status]
   buf:beTouched()
   return true
end
```


#### Sessionbuf:movePremise\{Up|Down\}\(\)

Moves the selected premise up/back or down/forward in the session\.

\#todo
For now, we assume the user knows what they're doing, and they can always
use `br session update` to fix things separately\.

```lua
local function _swapPremises(buf, index_a, index_b)
   local premise_a = buf.value[index_a]
   local premise_b = buf.value[index_b]
   buf.value[index_a] = premise_b
   buf.txtbufs[index_a]:replace(premise_b.line)
   premise_b.ordinal = index_a
   buf.value[index_b] = premise_a
   buf.txtbufs[index_b]:replace(premise_a.line)
   premise_a.ordinal = index_b
   buf:clearCaches()
end

function Sessionbuf.movePremiseUp(buf)
   if buf.selected_index == 1 then
      return false
   end
   _swapPremises(buf, buf.selected_index, buf.selected_index - 1)
   -- Maintain selection of the same premise after the move
   -- Will never wrap because we disallowed moving the first premise up
   buf:selectPreviousWrap()
   return true
end

function Sessionbuf.movePremiseDown(buf)
   if buf.selected_index == #buf.value then
      return false
   end
   _swapPremises(buf, buf.selected_index, buf.selected_index + 1)
   buf:selectNextWrap()
   return true
end
```


### Rendering


#### Sessionbuf:clearCaches\(\)

Although we have sub\-buffers, their caches will usually remain valid
even when ours does not, so leave them alone\.
Discard any render coroutine we may be holding on to\.

```lua
function Sessionbuf.clearCaches(buf)
   buf:super"clearCaches"()
   buf._composeOneLine = nil
end
```


#### Sessionbuf:initComposition\(\)

```lua
local wrap = assert(coroutine.wrap)
function Sessionbuf.initComposition(buf)
   buf._composeOneLine = buf._composeOneLine or
      wrap(function() buf:_composeAll() end)
end
```


#### Sessionbuf:\_composeAll\(\)

Given the amount of state involved in our render process, it's easier
to just do it all as a coroutine\. This method is the body of that coroutine,
and we assign the wrapped result dynamically to `_composeOneLine`

```lua
local status_icons = {
   ignore = "🟡",
   accept = "✅",
   reject = "🚫",
   skip   = "🗑 "
}

local box_light = assert(require "anterm:box" . light)
local yield = assert(coroutine.yield)
local c = assert(require "singletons:color" . color)
function Sessionbuf._composeAll(buf)
   for i, premise in ipairs(buf.value) do
      yield(i == 1
         and box_light:topLine(buf:contentCols())
         or box_light:spanningLine(buf:contentCols()))
      -- Render the line (which could actually be multiple physical lines)
      local line_prefix = box_light:contentLine(buf:contentCols()) ..
         status_icons[premise.status] .. ' '
      for line in buf.txtbufs[i]:lineGen() do
         -- Selected premise gets a highlight
         if i == buf.selected_index then
            line = c.highlight(line)
         end
         yield(line_prefix .. line)
         line_prefix = box_light:contentLine(buf:contentCols()) .. '   '
      end
      -- Selected premise also displays results
      if i == buf.selected_index then
         yield(box_light:spanningLine(buf:contentCols()))
         for line in buf.resbuf:lineGen() do
            yield(box_light:contentLine(buf:contentCols()) .. line)
         end
      end
   end
   if #buf.value == 0 then
      yield(box_light:topLine(buf:contentCols()))
      yield(box_light:contentLine(buf:contentCols()) .. "No premises to display")
   end
   yield(box_light:bottomLine(buf:contentCols()))
   buf._composeOneLine = nil
end
```


### Sessionbuf:\_init\(\)

We have a Resbuf and an array of Txtbufs to initialize\.

```lua
function Sessionbuf._init(buf)
   buf:super"_init"()
   buf.resbuf = Resbuf({ n = 0 }, { scrollable = true })
   buf.txtbufs = {}
end
```


### Sessionbuf:replace\(session\)

```lua
local lua_thor = assert(require "helm:lex" . lua_thor)
function Sessionbuf.replace(buf, session)
   buf:super"replace"(session)
   for i, premise in ipairs(session) do
      if buf.txtbufs[i] then
         buf.txtbufs[i]:replace(premise.line)
      else
         buf.txtbufs[i] = Txtbuf(premise.line, { lex = lua_thor })
      end
   end
   for i = #session + 1, #buf.txtbufs do
      buf.txtbufs[i] = nil
   end
   buf:selectIndex(1)
end
```

```lua
local Sessionbuf_class = setmetatable({}, Sessionbuf)
Sessionbuf.idEst = Sessionbuf_class

return Sessionbuf_class
```

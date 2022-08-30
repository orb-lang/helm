# Reviewbuf

This is a type of `Rainbuf` specialized to display and edit a
`Run` or `Session`\.


## Instance fields


-  txtbufs:        Array of `Txtbuf`s for each line of the session\.

-  resbuf:         `Resbuf` for displaying the results of the selected line\.

## Source protocol

We have more requirements for our `source` than many buffers, because of
our use of sub\-buffers\. In addition to the usual \.bufferValue\(\), we need:


-  selected\_index:     Integer index of the premise selected for editing\.

-  selectedPremise\(\):  Convenience function, retrieve the actual selected premise\.

-  editWindow\(index\):  Retrieve a window to use as the source for the Txtbuf
    displaying the line for the `index`th premise\.

-  resultsWindow\(\):    Retrieve a window to use as the source for the Resbuf
    displaying the results of the selected premise\.

```lua
local Rainbuf = require "helm:buf/rainbuf"
local Resbuf  = require "helm:buf/resbuf"
local Txtbuf  = require "helm:buf/txtbuf"

local Reviewbuf = meta(getmetatable(Rainbuf))

local math = core.math
```


## Constants

```lua
-- The (maximum) number of rows we will use for the "line" (command)
-- (in case it is many lines long)
Reviewbuf.ROWS_PER_LINE = 4
-- The (maximum) number of rows we will use for the result of the selected line
Reviewbuf.ROWS_PER_RESULT = 7
```


## Methods


### Reviewbuf:contentCols\(\)

We have left and right borders, which immediately take off two columns of
width\. Padding matters too, but only to our sub\-buffers, so we can't account
for it here\.

```lua
function Reviewbuf.contentCols(buf)
   return Rainbuf.contentCols(buf) - 2
end
```


### Sub\-buffer management

We lazy\-create our subsidiary buffers\-\-centralize this with helper functions\.

```lua
local function _set_resbuf_extent(buf)
   if buf.resbuf then
      -- Account for additional padding
      buf.resbuf:setExtent(buf.ROWS_PER_RESULT, buf:contentCols() - 2)
   end
end

local function _set_txtbuf_extent(buf, index)
   if buf.txtbufs[index] then
      -- As above, but additionally three cells for the icon and space after it
      buf.txtbufs[index]:setExtent(buf.ROWS_PER_LINE, buf:contentCols() - 5)
   end
end

local function _resbuf(buf)
   if not buf.resbuf then
      buf.resbuf = Resbuf(buf.source.resultsWindow(), { scrollable = true })
      _set_resbuf_extent(buf)
   end
   return buf.resbuf
end

local lua_thor = assert(require "helm:lex" . lua_thor)
local function _txtbuf(buf, index)
   if not buf.txtbufs[index] then
      buf.txtbufs[index] = Txtbuf(buf.source.editWindow(index), { lex = lua_thor })
      _set_txtbuf_extent(buf, index)
   end
   return buf.txtbufs[index]
end
```


#### Reviewbuf:editAgentRemoved\(index\)

Communication from our backing Agent that it has removed a subsidiary agent at `index`
and we should remove the corresponding buffer if we have created one\.

```lua
function Reviewbuf.editAgentRemoved(buf, index)
   buf.txtbufs[index] = nil
end
```


### Reviewbuf:setExtent\(rows, cols\)

Pass through extent changes to our sub\-buffers as needed\. We extract this to a
function because it also needs to happen when we create new sub\-buffers\.

```lua
function Reviewbuf.setSubExtents(buf)
   if not (buf.rows and buf.cols) then return end
   _set_resbuf_extent(buf)
   -- There'll probably never be holes in the txtbufs array, but it doesn't
   -- really matter what order we do this in, so better safe than sorry.
   for index in pairs(buf.txtbufs) do
      _set_txtbuf_extent(buf, index)
   end
end

function Reviewbuf.setExtent(buf, rows, cols)
   Rainbuf.setExtent(buf, rows, cols)
   buf:setSubExtents()
end
```


### Reviewbuf:checkTouched\(\)

Changes to our sub\-buffers \(e\.g\. from scrolling\) also count as touches\. We
don't early\-out once we know we're touched because we must still check and
clear everyone\.

```lua
function Reviewbuf.checkTouched(buf)
   if buf.resbuf and buf.resbuf:checkTouched() then
      buf:beTouched()
   end
   for _, txtbuf in pairs(buf.txtbufs) do
      if txtbuf:checkTouched() then
         buf:beTouched()
      end
   end
   return Rainbuf.checkTouched(buf)
end
```


### Reviewbuf:rowsForSelectedResult\(\)

Returns the number of lines needed to display the result of the
selected premise\. This will never be greater than ROWS\_PER\_RESULT\.
The Reviewbuf must have had :initComposition\(\) already called\.

```lua
local clamp = assert(math.clamp)
function Reviewbuf.rowsForSelectedResult(buf)
   _resbuf(buf):composeUpTo(buf.ROWS_PER_RESULT)
   return clamp(#_resbuf(buf).lines, 0, buf.ROWS_PER_RESULT)
end
```


### Reviewbuf:positionOf\(index\)

Returns the line number at which display of the `index`th premise begins\.

```lua
local gsub = assert(string.gsub)
function Reviewbuf.positionOf(buf, index)
   local position = 1
   for i = 1, index - 1 do
      local line = buf:value()[i].round.line
      local num_lines = select(2, gsub(line, '\n', '\n')) + 1
      num_lines = clamp(num_lines, 1, buf.ROWS_PER_LINE)
      position = position + num_lines + 1
      if i == buf.source.selected_index then
         position = position + buf:rowsForSelectedResult() + 1
      end
   end
   return position
end

function Reviewbuf.positionOfSelected(buf)
   return buf:positionOf(buf.source.selected_index)
end
```


### Reviewbuf:ensureSelectedVisible\(\)

Ensures that the selected premise is visible, **including its results**\.

```lua
function Reviewbuf.ensureSelectedVisible(buf)
   local start_index = buf:positionOfSelected()
   local end_index = start_index + buf:rowsForSelectedResult() + 3
   buf:ensureVisible(start_index, end_index)
end
```


### Reviewbuf:processQueuedMessages\(\)

We must pass this message along to our sub\-buffers, and include them in our
answer of whether we did anything\.

```lua
function Reviewbuf.processQueuedMessages(buf)
   local had_any = false
   if buf.resbuf and buf.resbuf:processQueuedMessages() then
      had_any = true
   end
   for _, txtbuf in pairs(buf.txtbufs) do
      if txtbuf:processQueuedMessages() then
         had_any = true
      end
   end
   -- Anything from sub-buffers means we need to clear our line cache as well
   if had_any then
      buf:clearCaches()
   end
   if Rainbuf.processQueuedMessages(buf) then
      had_any = true
   end
   return had_any
end
```


### Rendering


#### Reviewbuf:clearCaches\(\)

Although we have sub\-buffers, their caches will usually remain valid
even when ours does not, so leave them alone\.
Discard any render coroutine we may be holding on to\.

```lua
function Reviewbuf.clearCaches(buf)
   Rainbuf.clearCaches(buf)
   buf._composeOneLine = nil
end
```


#### Reviewbuf:initComposition\(\)

```lua
local wrap = assert(coroutine.wrap)
function Reviewbuf.initComposition(buf)
   buf._composeOneLine = buf._composeOneLine or wrap(
      function()
         local success, err = xpcall(function() buf:_composeAll() end,
                                     debug.traceback)
         if not success then
            error(err)
         end
      end)
end
```


#### Reviewbuf:\_composeAll\(\)

Given the amount of state involved in our render process, it's easier
to just do it all as a coroutine\. This method is the body of that coroutine,
and we assign the wrapped result dynamically to `_composeOneLine`\.

```lua
local status_icons = {
   ignore = "🟡",
   accept = "✅",
   reject = "🚫",
   -- iTerm displays the trash-can emoji double-wide,
   -- but only advances the cursor one cell
   trash  = "🗑 ",
   keep   = "✅",
   insert = "👉"
}

local box_light = assert(require "anterm:box" . light)
local yield = assert(coroutine.yield)
local c = assert(require "singletons:color" . color)

function Reviewbuf._composeAll(buf)
   local function box_line(line_type)
      return box_light[line_type .. "Line"](box_light, buf:contentCols())
   end
   for i, premise in ipairs(buf:value()) do
      yield(box_line(i == 1 and "top" or "spanning"))
      -- Render the line (which could actually be multiple physical lines)
      local line_prefix = status_icons[premise.status] .. ' '
      for line in _txtbuf(buf, i):lineGen() do
         -- Selected premise gets a highlight
         if i == buf.source.selected_index then
            line = c.highlight(line)
         end
         yield(box_line"content" .. line_prefix .. line)
         line_prefix = '   '
      end
      -- Selected premise also displays results
      if i == buf.source.selected_index then
         yield(box_line"spanning")
         for line in _resbuf(buf):lineGen() do
            yield(box_line"content" .. line)
         end
      end
   end
   if #buf:value() == 0 then
      yield(box_line"top")
      yield(box_line"content" .. "No premises to display")
   end
   yield(box_line"bottom")
   buf._composeOneLine = nil
end
```


### Reviewbuf:\_init\(\)

We have an array of Txtbufs to initialize, though we leave it empty and fill
it lazily\. We also defer creating a Resbuf until we need it, since we need to
have our source window in order to do so\.

```lua
function Reviewbuf._init(buf)
   Rainbuf._init(buf)
   buf.txtbufs = {}
end
```


```lua
return core.cluster.constructor(Reviewbuf)
```

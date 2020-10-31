# Sessionbuf

This is a type of `Rainbuf` specialized to display and edit a `Session`\.


## Instance fields


-  session:        The Session object we are displaying and editing\.

-  resbuf:         `Resbuf` for displaying the results of the selected line\.

-  selected\_index: The index of the line that is selected for editing

```lua
local Rainbuf = require "helm:rainbuf"
local Resbuf  = require "helm:resbuf"

local Sessionbuf = Rainbuf:inherit()
```


## Constants

```lua
Sessionbuf.LINES_PER_RESULT = 7
```


## Methods


### Sessionbuf:clearCaches\(\)

We have a `Resbuf` for each of our lines, pass the message along\.
Also reset our notion of which line we're working on\.

```lua
function Sessionbuf.clearCaches(buf)
   buf:super"clearCaches"()
   buf.resbuf:clearCaches()
   buf._composeOneLine = nil
end
```


### Sessionbuf:initComposition\(cols\)

```lua
local wrap = assert(coroutine.wrap)
function Sessionbuf.initComposition(buf, cols)
   buf:super"initComposition"(cols)
   buf._composeOneLine = wrap(function() buf:_composeAll() end)
end
```


### Sessionbuf:\_composeAll\(cols\)

Given the amount of state involved in our render process, it's easier
to just do it all as a coroutine\. This method is the body of that coroutine,
and we assign the wrapped result dynamically to `_composeOneLine`

```lua
local status_icons = {
   accept = "✅",
   reject = "❌",
   ignore = "🟡",
   skip   = "🚫"
}

local box_light = assert(require "anterm:box" . light)
local yield = assert(coroutine.yield)
local c = assert(require "singletons:color" . color)
function Sessionbuf._composeAll(buf)
   local inner_cols = buf.cols - 2 -- For the box borders
   for i, premise in ipairs(buf.session) do
      yield(i == 1
         and box_light:topLine(inner_cols)
         or box_light:spanningLine(inner_cols))
      -- #todo use a Txtbuf to render the line, in order to have
      -- syntax highlighting, and also auto-truncation/wrapping
      -- once we implement that
      local line = box_light:contentLine(inner_cols) ..
         status_icons[premise.status] .. ' '
      -- Selected premise gets a highlight and displays results
      if i == buf.selected_index then
         yield(line .. c.highlight(premise.line))
         yield(box_light:spanningLine(inner_cols))
         -- No need for left padding inside the box, the Rainbuf has a
         -- 3-column gutter anyway. Do want to leave 1 column of right padding
         for line in buf.resbuf:lineGen(buf.LINES_PER_RESULT, inner_cols - 1) do
            yield(box_light:contentLine(inner_cols) .. line)
         end
      -- Others just get the line itself
      else
         yield (line .. premise.line)
      end
   end
   yield(box_light:bottomLine(inner_cols))
end
```


### Sessionbuf:\_init\(\)

We have an array of sub\-Resbufs to initialize\.

```lua
function Sessionbuf._init(buf)
   buf:super"_init"()
   buf.resbuf = {}
end
```


### Sessionbuf:replace\(session\)

```lua
function Sessionbuf.replace(buf, session)
   buf.session = session
   buf.selected_index = 1
   -- #todo evaluate the session and display the new result,
   -- along with whether there is a change
   buf.resbuf = Resbuf(session[1].old_result or { n = 0 }, { scrollable = true })
end
```

```lua
local Sessionbuf_class = setmetatable({}, Sessionbuf)
Sessionbuf.idEst = Sessionbuf_class

return Sessionbuf_class
```

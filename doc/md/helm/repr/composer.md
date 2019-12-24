# Composer

The Composer class is responsible for injesting [[Tokens][~/helm/token]] and
emitting [[Reslines][~/helm/resbuf#Resline]].


## Interface

### Instance Fields

-  token_source : An iterator function returning ``Token``s to be
   arranged into lines.
-  color : The color table to use.
-  width : The width in which to fit the output.
-  more : Are more tokens available from the token_source?
-  level : The indent level as of the start of the current line. #stages is
   the equivalent at the current position.
-  stages : Stack of tables representing the type (array, map, others TBD)
   and printing mode (short or long) of each level of nesting entered
   and not finished at this point in the stream. Includes a dummy entry at
   index 0 for the case where we are printing something other than a table.

## Dependencies

```lua

local meta = require "singletons/core" . meta
local Token = require "helm/repr/token"

local concat, insert, remove = assert(table.concat),
                               assert(table.insert),
                               assert(table.remove)

```
## Methods

```lua

local Composer = meta {}
local new

```
#### Composer:disp()

Computes and returns the displacement of the candidate tokens that will make
up the next line emitted by the composer, including the initial indent if any.

```lua
function Composer.disp(composer)
   local disp = composer[1].wrapped and 0 or 2 * composer.level
   for i = 1, composer.pos do
      disp = disp + composer[i].total_disp
   end
   return disp
end
```
#### Composer:remains()

Returns the remaining displacement available on the current line.

```lua
function Composer.remains(composer)
   return composer.width - composer:disp()
end
```
#### Composer:peek()

Answers the next token (at pos + 1), retrieving it from the token_source
if necessary. Does not advance the composer or handle events.

```lua
function Composer.peek(composer)
   if composer.more and not composer[composer.pos + 1] then
      composer[composer.pos + 1] = composer.token_source()
   end
   if not composer[composer.pos + 1] then
      composer.more = false
   end
   return composer[composer.pos + 1]
end
```
#### Composer:advance()

Advances the composer by one token, either inspecting a token already
retrieved from the token_source and subsequently "put back", or retrieving
a new one. Answers the new current token and stage.

```lua

function Composer.advance(composer)
   local token = composer:peek()
   if token then
      composer.pos = composer.pos + 1
   end
   return token, composer.stages[#composer.stages]
end
```
#### Composer:checkPushStage()

Pushes a stage if indicated by the current token's event.
Returns the active stage (whether it has changed or not).
Does **not** update composer.level, as this needs to reflect the indent level
as of the **start** of the current line.

```lua
local STAGED_EVENTS = {
   array = true,
   map = true
}

function Composer.checkPushStage(composer)
   local token = composer[composer.pos]
   if STAGED_EVENTS[token.event] then
      insert(composer.stages, {
         start_token = token,
         event = token.event,
         long = false
      })
   end
   return composer.stages[#composer.stages]
end
```
#### Composer:checkPopStage()

Pops a stage if indicated by the current token's event.
Returns the active stage (whether it has changed or not).
Does **not** update composer.level, as this needs to reflect the indent level
as of the **start** of the current line.


The logic for when to pop a stage is somewhat complex in order to avoid
wrapping separators when a child table **exactly** fits in short mode.
Essentially, we don't consider the stage complete until the trailing separator,
if any, has been processed as well.


This can still have problems at the end of a deeply-nested table, when
encountering lots of closing braces in a row. Technically we might want to
refuse to end the stage until **all** closing braces until the next separator
have been consumed. But this makes the logic much more complicated, and really,
maybe "wrapping" a brace is better than entering long mode in that case.

```lua
function Composer.checkPopStage(composer)
   local token = composer[composer.pos]
   if token.event == "end" then
      local next_token = composer:peek()
      -- If the following token is a separator, don't end the stage here...
      if not (next_token and next_token.event == "sep") then
         remove(composer.stages)
      end
   elseif token.event == "sep" then
      local prev = composer[composer.pos - 1]
      -- ...because, if we encounter a separator and the *previous* token
      -- is an =end=, *now* it's time to end the stage
      if prev and prev.event == "end" then
         remove(composer.stages)
      end
   end
   return composer.stages[#composer.stages]
end
```
#### Composer:enterLongMode()

Enters long printing mode for the first stage that is still in short mode
and resets the composer to retry formatting that stage.

```lua
function Composer.enterLongMode(composer)
   for i = 1, composer.level do
      assert(composer.stages[i].long,
         "Cannot print a long stage inside a short one")
   end
   local long_stage_index = composer.level
   local stage
   repeat
      long_stage_index = long_stage_index + 1
      stage = composer.stages[long_stage_index]
      assert(stage, "No new stage to put in long mode")
   until not stage.long
   stage.long = true
   for i = long_stage_index + 1, #composer.stages do
      composer.stages[i] = nil
   end
   for i, token in ipairs(composer) do
      if token == stage.start_token then
         composer.pos = i
         return token, composer.stages[#composer.stages]
      end
   end
   error("Could not find start of stage")
end
```
#### Composer:emit()

Emits a line consisting of the tokens inspected so far, i.e.
composer[1..composer.pos].

```lua
function Composer.emit(composer)
   if composer.pos == 0 then
      return nil
   end
   local output = {}
   if not composer[1].wrapped then
      insert(output, ("  "):rep(composer.level))
   end
   for i = 1, composer.pos do
      insert(output, composer[i]:toString(composer.color))
   end
   -- Erase what we just copied to the output and shift
   -- any remaining tokens back
   for i = 1, #composer do
      if i > composer.pos then
         composer[i - composer.pos] = composer[i]
      end
      composer[i] = nil
   end
   composer.pos = 0
   composer.level = #composer.stages
   return concat(output)
end
```
#### Composer:splitToken()

Splits the current token to fit in the remaining space on the line, and inserts
a ~ at the end of the line to indicate that it has been wrapped. If the current
token is shorter than 20 characters, or is not marked wrappable, it is moved
entirely to the next line instead.

```lua
local MIN_SPLIT_WIDTH = 20

function Composer.splitToken(composer, token)
   local token = composer[composer.pos]
   -- Step back one token to exclude the one we're about to split
   composer.pos = composer.pos - 1
   -- Reserve one space for the ~ indicating a wrapped line
   local remaining = composer:remains() - 1
   token.wrapped = true
   -- Only split strings, and only if they're long enough to be worth it
   -- In the extreme event that a non-string token is longer than the
   -- entire available width, split it too to avoid an infinite loop
   if token.wrappable and token.total_disp > MIN_SPLIT_WIDTH
      or token.total_disp >= composer.width then
      token = token:split(remaining)
      -- Pad with spaces if we were forced to split a couple chars short
      for i = 1, remaining - token.total_disp do
         token:insert(" ")
      end
   -- Short strings and other token types just get bumped to the next line
   else
      token = Token((" "):rep(remaining), composer.color.no_color)
   end
   -- Done splitting, step forward again
   composer.pos = composer.pos + 1
   insert(composer, composer.pos, token)
   -- Leave the ~ ready to be consumed by the next advance()--we need to finish
   -- processing the first half of the split first.
   insert(composer, composer.pos + 1, Token("~", composer.color.alert, { event = "break" }))
   return token
end
```
#### Composer:composeLine()

Composes and emits one line, consuming tokens as needed from token_source.
Also available as Composer.__call--a Composer is also an iterator function.

```lua
function Composer.composeLine(composer)
   repeat
      local token = composer:advance()
      if not token then
         break
      end
      local stage = composer:checkPushStage()
      if not stage then
         error("No stage while processing: " .. token:toStringBW())
      end
      if (token.event == "repr_line" or token.event == "break")
         and not stage.long then
         token, stage = composer:enterLongMode()
      end
      -- If we know we are going to end the line after this token no matter
      -- what, we can allow it to exactly fill the line--no need to reserve
      -- space for a ~. We can also ignore any trailing spaces it may contain.
      local reserved_space = 1
      if token.event == "sep" and stage.long
         or token.event == "break" then
         token:removeTrailingSpaces()
         reserved_space = 0
      end
      if composer:remains() < reserved_space then
         assert(token.event ~= "break", "~ token overflowing line")
         if not stage.long and stage.start_token ~= token then
            token, stage = composer:enterLongMode()
         -- Never wrap output from __repr--likely to do more harm than good
         -- until/unless we can parse out color escape sequences
         elseif token.event ~= "repr_line" then
            token = composer:splitToken()
         end
      end
      stage = composer:checkPopStage()
   until token.event == "sep" and stage.long
         or token.event == "break"
         or token.event == "repr_line"
   return composer:emit()
end

Composer.__call = Composer.composeLine
```
### Composer:window()

This method produces a window table into the relevant data inside a Composer.


It is passed to a custom ``__repr`` metamethod, to provide information it can
use to return data to the composer.


``composer:remains()`` will return the amount of printable columns remaining in
the line.  It may need to make some calculations to the existing stream.


``composer:case()`` will return e.g. ``"map_val"``, ``"map_key"``, ``"array"``,
or ``"outer"`` if we're in the outer printing context (not in a nested table).

```lua

local FUNCTION_WINDOWS = {
   remains = true,
   case = true
}

local FIELD_WINDOWS = {
   width = true,
   color = true
}

local function make_window__index(composer, field)
   return function(window, field)
      if FIELD_WINDOWS[field] then
         return composer[field]
      elseif FUNCTION_WINDOWS[field] then
         return composer[field]()
      else
         error ("window has no method " .. field .. "n" .. debug.traceback())
      end
   end
end

local function _window__newindex(window, key, value)
   error("window is read only : {" .. tostring(key) .. tostring(value) .. "}",
      debug.traceback())
end

function Composer.window(composer)
   local window = setmetatable({}, { __index = make_window__index(composer),
      __newindex = _window__newindex})
   return window
end
```
### new(iter_gen, cfg)

```lua

local function new(iter_gen, cfg)
   cfg = cfg or {}
   local function generator(val, disp_width, color)
      assert(color, "Must provide a color table to Composer")
      local composer = setmetatable({
         color = color,
         width = disp_width or 80,
         more = true,
         pos = 0,
         stages = {[0] = { long = true }},
         level = 0,
         long = false
      }, Composer)
      for k,v in pairs(cfg) do
        composer[k] = v
      end
      composer.token_source = iter_gen(val, composer:window(), color)
      return composer
   end
   return generator
end

Composer.idEst = new

return new

```

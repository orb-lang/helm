

























local meta = require "core/meta" . meta
local Token = require "helm/repr/token"

local concat, insert, remove = assert(table.concat),
                               assert(table.insert),
                               assert(table.remove)







local Composer = meta {}
local new









function Composer.disp(composer)
   local disp = 2 * composer.level
   -- If the first token is the second half of a wrap, skip the indent
   if composer.pos > 0 and composer[1].wrapped then
      disp = 0
   end
   for i = 1, composer.pos do
      disp = disp + composer[i].total_disp
   end
   return disp
end







function Composer.remains(composer)
   return composer.width - composer:disp()
end








function Composer.peek(composer)
   if composer.more and not composer[composer.pos + 1] then
      composer[composer.pos + 1] = composer.token_source()
   end
   if not composer[composer.pos + 1] then
      composer.more = false
   end
   return composer[composer.pos + 1]
end










function Composer.advance(composer)
   local token = composer:peek()
   if token then
      composer.pos = composer.pos + 1
   end
   return token, composer.stages[#composer.stages]
end










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
         return composer[field](composer)
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





local GUTTER_WIDTH = 3

local function new(iter_gen, cfg)
   cfg = cfg or {}
   local function generator(val, disp_width, color)
      assert(color, "Must provide a color table to Composer")
      -- For now, account for the fact that there will be a 3-column gutter
      -- Eventually we'll probably be producing the metadata as well
      local width = disp_width and disp_width - GUTTER_WIDTH or 80
      local composer = setmetatable({
         color = color,
         width = width,
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


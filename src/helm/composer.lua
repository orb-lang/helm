






















local meta = assert(meta)
local Token = require "helm/token"

local concat, insert, remove = assert(table.concat),
assert(table.insert),
assert(table.remove)







local Composer = meta {}
local new











local function _disp(token_array)
   local displacement = 0
   for _, token in ipairs(token_array) do
      displacement = displacement + token.total_disp
   end
   return displacement
end

Composer.disp = _disp

local function _spill(composer, line)
   if line[1].event == "indent" then
      remove(line, 1)
   end
   for i = 1, #line do
      composer[i] = line[i]
   end
   return false
end

function Composer.remains(composer)
   return composer.width - composer:disp()
end

local MIN_SPLIT_WIDTH = 20

local function oneLine(composer, force)
   if #composer == 0 then
      return false
   end
   local c = composer.color
   local line = { Token(("  "):rep(composer.level), c.no_color, {event = "indent"}) }
   local new_level = composer.level
   while true do
      local token = remove(composer, 1)
      -- Don't indent the remainder of a wrapped token
      if token.wrap_part == "rest" then
         assert(remove(line).event == "indent", "Should only encounter rest-of-wrap at start of line")
      end
      insert(line, token)
      if token.event == "array" or token.event == "map" then
         new_level = new_level + 1
      elseif token.event == "end" then
         new_level = new_level - 1
      end
      -- If we are in long mode and hit a separator, remove the trailing space
      -- so it doesn't cause an unnecessary wrap. We can also allow the line to
      -- exactly fill the buffer, since we know we're going to end the line
      -- here anyway.
      local reserved_space = 1
      if token.event == "sep" and composer.long then
         token:removeTrailingSpaces()
         reserved_space = 0
      end
      if _disp(line) + reserved_space > composer.width then
         remove(line)
         -- Now that we know we *are* going to force-wrap, we need space for
         -- the ~ even if this token is a separator (in which case it will
         -- end up entirely on the next line, but we need to compute the
         -- number of padding spaces correctly).
         local remaining = composer.width - _disp(line) - 1
         local rest = token
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
         token = Token((" "):rep(remaining), c.no_color)
      end
      token.wrap_part = "first"
      rest.wrap_part = "rest"
      insert(line, token)
      insert(line, Token("~", c.alert))
      insert(composer, 1, rest)
   end
      -- If we are in long mode and hit a comma
      if (token.event == "sep" and composer.long)
         -- Or we are at the very end of the stream,
         -- or have been told to produce a line no matter what
         or (#composer == 0 and (force or not composer.more))
         -- Or we just needed to chop & wrap a token
         or (token.wrap_part == "first") then
            for i, frag in ipairs(line) do
               line[i] = frag:toString(c)
            end
            composer.level = new_level
            return concat(line)
      elseif #composer == 0 and composer.more then
         -- spill our fragments back
         return _spill(composer, line)
      end
   end
end







local function lineGen(composer)
   while composer.more do
      local ln = oneLine(composer)
      if ln then
         return ln
      end
      local token = composer.token_source()
      if token == nil then
         composer.more = false
         return oneLine(composer)
      end
      if token.event == "repr_line" then
         -- Clear the buffer, if any, then pass along the __repr() output
         local prev = oneLine(composer, true) or ""
         return prev .. token.str
      end
      insert(composer, token)
      composer.long = (composer:disp() + (2 * composer.level) >= composer.width)
   end
end

Composer.__call = lineGen

















local function make_window__index(composer, field)
   return function(composer, field)
      if field == "remains" then
         return composer:remains()
      elseif field == "case" then
         return composer:case()
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






local function new(iter_gen, cfg)
   cfg = cfg or {}
   local function generator(val, disp_width, color)
      local composer = setmeta({
         color = color or C.no_color,
         width = disp_width or 80,
         more = true,
         stages = {},
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


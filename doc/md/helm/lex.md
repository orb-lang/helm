# Lex


We're going to do this will straight el peg, and fold in ``espalier`` ASAP.

```lua
local L = require "lpeg"
local P, R, S, match = L.P, L.R, L.S, L.match
local Lex = meta {}
local sub, gsub = assert(string.sub), assert(string.gsub)
local concat = assert(table.concat)
local c = require "singletons/color"
local codepoints = assert(string.codepoints)
```
### Lua lexers

```lua
local WS = (P" ")^1

local NL = P"\n"

local terminal = S" \"'+-*^~%#;,<>={}[]().:\n" + -P(1)

local KW = (P"function" + "local" + "for" + "in" + "do"
           + "and" + "or" + "not" + "true" + "false"
           + "while" + "break" + "if" + "then" + "else" + "elseif"
           + "goto" + "repeat" + "until" + "return" + "nil"
           + "end") * #terminal

local OP = P"+" + "-" + "*" + "/" + "%" + "^" + "#"
           + "==" + "~=" + "<=" + ">=" + "<" + ">"
           + "=" + "(" + ")" + "{" + "}" + "[" + "]"
           + ";" + ":" + "..." + ".." + "." + ","

local digit = R"09"

local _decimal = P"-"^0 * ((digit^1 * P"."^-1 * digit^0
                           * ((P"e" + P"E")^-1 * P"-"^-1 * digit^1)^-1
                        + digit^1)^1 + digit^1)

local higit = R"09" + R"af" + R"AF"

-- hexadecimal floats. are a thing. that exists. in luajit.
local _hexadecimal = P"-"^0 * P"0" * (P"x" + P"X")
                        * ((higit^1 * P"."^-1 * higit^0
                           * ((P"p" + P"P")^-1 * P"-"^-1 * higit^1)^-1
                        + higit^1)^1 + higit^1)

-- long strings, straight from the LPEG docs
local _equals = P"="^0
local _open = "[" * L.Cg(_equals, "init") * "[" * P"\n"^-1
local _close = "]" * L.C(_equals) * "]"
local _closeeq = L.Cmt(_close * L.Cb("init"),
                          function (s, i, a, b) return a == b end)

local long_str = (_open * L.C((P(1) - _closeeq)^0) * _close) / 0 * L.Cp()

local str_esc = P"\\" * (S"abfnrtvz\\'\"[]\n"
                         + (R"09" * R"09"^-2)
                         + (P"x" + P"X") * higit * higit)

local double_str = P"\"" * (P(1) - (P"\"" + P"\\") + str_esc)^0 * P"\""
local single_str = P"\'" * (P(1) - (P"\'" + P"\\") + str_esc)^0 * P"\'"

local string_short = double_str + single_str

local string_long = long_str

local letter = R"az" + R"AZ"

local symbol =   (letter^1 + P"_"^1)
               * (letter + digit + P"_")^0
               * #terminal

local number = _hexadecimal + _decimal

local comment = P"--" * long_str
              + P"--" * (P(1) - NL)^0 * (NL + - P(1))

local ERR = P(1)^1

local lua_toks = {comment, KW, string_long, string_short, number, OP, symbol,
                  WS, NL, ERR}

local lex_kv = { KW = KW,
                 number = number,
                 OP = OP,
                 symbol = symbol,
                 string_long = string_long,
                 string_short = string_short,
                 comment = comment,
                 WS = WS,
                 NL = NL,
                 ERR = ERR}

local color_map = {
   KW = c.color.keyword(),
   OP = c.color.operator(),
   number = c.color.number(),
   symbol = c.color.field(),
   string_short = c.color.string(),
   string_long = c.color.string(),
   comment = c.color.comment(),
   ERR = c.color.error(),
   NL = a.clear(),
}


local lex_map = {}

for k, v in pairs(lex_kv) do
   lex_map[v] = k
end

lex_kv = nil

Lex.lex_map = lex_map

Lex.long_str = long_str
Lex.string = string_long
```
## Lex.lua_thor(txtbuf)

...it's late.


### chomp_token(lb)

This is an almost pessimal way to use ``lpeg``, which is quite capable of
handling a full line in one pass.

```lua
local function chomp_token(lb)
   for _,v in ipairs(lua_toks) do
      local bite = match(v, lb)
      if bite ~= nil then
         return sub(lb, 1, bite - 1), sub(lb, bite), v
      end
   end
   return nil
end

Lex.chomp = chomp_token


-- a bit of finesse to mark up strings with quotemarks.
--

local function _str_hl(str)
   local mark = sub(str,1,1) == "'" and "'" or '"'
   mark = c.color.string(mark)
   return mark .. ts(str) .. mark
end


function Lex.lua_thor(txtbuf)
   local toks = {}
   local wid = {}
   local lb = tostring(txtbuf)
   while lb ~= "" do
      local len = #lb
      local bite, tok_t
      bite, lb, tok_t = chomp_token(lb)
      if bite == nil then
         break
      else
         local col = color_map[lex_map[tok_t]]
         if col then
            toks[#toks + 1] = col
            wid[#wid + 1]   = 0
            toks[#toks + 1] = bite
            wid[#wid + 1]   = #bite
         elseif tok_t == string_short then
            toks[#toks + 1] = _str_hl(bite)
            wid[#wid + 1] = #bite
         else
            toks[#toks + 1] = bite
            wid[#wid + 1] = #bite
         end
      end
      if len == #lb then
         error "lua-thor has failed you"
      end
   end
   toks[#toks + 1] = a.clear()
   wid[#wid + 1] = 0
   return toks, wid
end
```
```lua
return Lex
```

# Lex


We're going to do this will straight el peg, and fold in ``espalier`` ASAP.

```lua
local L = require "lpeg"
local P, R, S, match = L.P, L.R, L.S, L.match
local Lex = meta {}
local sub, gsub = assert(string.sub), assert(string.gsub)
local concat, insert = assert(table.concat), assert(table.insert)
local c = require "singletons/color"
```
### Lua lexers

```lua
local WS = (P" ")^1

local NL = P"\n"

local terminal = S" \"'+-*^~%#;,<>={}[]().:\n" + -P(1)

local keyword = (P"function" + "local" + "for" + "in" + "do"
           + "and" + "or" + "not" + "true" + "false"
           + "while" + "break" + "if" + "then" + "else" + "elseif"
           + "goto" + "repeat" + "until" + "return" + "nil"
           + "end") * #terminal

local operator = P"+" + "-" + "*" + "/" + "%" + "^" + "#"
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

local symbol =   (-digit * -terminal * P(1))^1
               * (-terminal * P(1))^0
               * #terminal

local number = _hexadecimal + _decimal

local comment = P"--" * long_str
              + P"--" * (P(1) - NL)^0 * (NL + - P(1))

local ERR = P(1)^1

local lua_toks = {comment, keyword, string_long, string_short, number, operator, symbol,
                  WS, NL, ERR}

local color_map = {
   [keyword] = c.color.keyword,
   [operator] = c.color.operator,
   [number] = c.color.number,
   [symbol] = c.color.field,
   [string_short] = c.color.string,
   [string_long] = c.color.string,
   [comment] = c.color.comment,
   [ERR] = c.color.error,
}

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

local Token = require "helm/repr/token"

function Lex.lua_thor(txtbuf)
   local toks = {}
   local lb = tostring(txtbuf)
   while lb ~= "" do
      local bite, tok_t
      bite, lb, tok_t = chomp_token(lb)
      if bite then
         assert(#bite > 0, "lua-thor has failed you")
         local col = color_map[tok_t] or c.no_color
         local cfg = {}
         -- Would love to highlight escape sequences in strings,
         -- but this turns out to be rather difficult...
         insert(toks, Token(bite, col, cfg))
      end
   end
   return toks
end
```
```lua
return Lex
```







local L = require "lpeg"
local P, R, S, match = L.P, L.R, L.S, L.match
local Lex = meta {}
local Rainbuf = require "rainbuf"
local sub = assert(string.sub)
local c = require "color"






local WS = (P" ")^0

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
           + ";" + ";" + "..." + ".." + "." + ","

-- long strings, straight from the LPEG docs

local _equals = P"="^0
local _open = "[" * L.Cg(_equals, "init") * "[" * P"\n"^-1
local _close = "]" * L.C(_equals) * "]"
local _closeeq = L.Cmt(_close * L.Cb("init"),
                          function (s, i, a, b) return a == b end)

local long_str = (_open * L.C((P(1) - _closeeq)^0) * _close) / 0 * L.Cp()

-- #todo valid escape sequences instead of P(1)s in below    ↓

local double_str = P"\"" * (P(1) - (P"\"" + P"\\") + P"\\" * P(1))^0 * P"\""
local single_str = P"\'" * (P(1) - (P"\'" + P"\\") + P"\\" * P(1))^0 * P"\'"

local string_P = double_str + single_str + long_str

local digit = R"09"

local letter = R"az" + R"AZ"

local symbol =   (letter^1 + P"_"^1)
               * (letter + digit + P"_")^0
               * #terminal

local _digital = P"-"^0 * ((digit^1 * P"."^-1 * digit^0
                           * ((P"e" + P"E")^-1 * P"-"^-1 * digit^1)^-1
                        + digit^1)^1 + digit^1)

local _hexadecimal = P"0" * (P"x" + P"X") * (digit + R"af" + R"AF")^1

local number = _digital

local comment = P"--" * long_str
              + P"--" * (P(1) - NL)^0 * (NL + - P(1))


local ERR = P(1)

local lua_toks = {comment, KW, string_P, number, OP, symbol,
                  WS, NL, ERR}

local lex_kv = { KW = KW,
                 number = number,
                 OP = OP,
                 symbol = symbol,
                 string = string_P,
                 comment = comment,
                 WS = WS,
                 NL = NL,
                 ERR = ERR}

local color_map = {
   KW = c.color.keyword(),
   OP = c.color.operator(),
   number = c.color.number(),
   symbol = c.color.field(),
   string = c.color.string(),
   comment = c.color.comment(),
   ERR = c.color.error(),
}


local lex_map = {}

for k, v in pairs(lex_kv) do
   lex_map[v] = k
end

lex_kv = nil

Lex.lex_map = lex_map

Lex.long_str = long_str
Lex.string = string_P














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

function Lex.lua_thor(linebuf)
   local toks = {}
   local lb = tostring(linebuf)
   while lb ~= "" do
      local len = #lb
      local bite, tok_t
      bite, lb, tok_t = chomp_token(lb)
      if bite == nil then
         break
      else
         -- #todo add a color
         local col = color_map[lex_map[tok_t]]
         if col then
            toks[#toks + 1] = col
         end
         toks[#toks + 1] = bite

      end
      if len == #lb then
         toks[#toks + 1] = a.clear .. color_map.ERR
         toks[#toks + 1] = sub(lb, 1, 1)
         lb = sub(lb,2)
      end
   end
   toks[#toks + 1] = a.clear()
   return toks
end




return Lex

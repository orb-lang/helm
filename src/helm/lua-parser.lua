















local Peg  = require "espalier:espalier/peg"
local Node = require "espalier:espalier/node"






local lua_str = [=[
lua = shebang* _ chunk _ finalcomment* Error*
shebang = "#" (!"\n" 1)* "\n"
chunk = _ (statement _ ";"?)* (_ laststatement _ (";")?)?

Error = 1+

finalcomment = "--" 1* !1

statement = "do" t chunk "end" t
          / "while" t expr "do" t chunk "end" t
          / "repeat" t chunk "until" t expr
          / "if" t expr "then" t chunk
            ("elseif" t expr "then" t chunk)*
            ("else" t chunk)* "end" t
          / "for" t _ symbol _ "=" expr _ "," _ expr _ ("," _ expr)?
            _ "do" t chunk "end" t
          / "for" t _ symbollist _ "in" t expr "do" t chunk "end" t
          / "function" t _ funcname _ funcbody
          / "local" t _ "function" t _ symbol _ funcbody
          / "local" t _ symbollist _ ("=" _ explist)?
          / varlist _ "=" _ explist
          / "goto" t _ symbol
          / "::" symbol "::"
          / functioncall

laststatement = "return" t (_ explist)?
              / "break" t

funcname = symbol _ ("." _ symbol)* (":" _ symbol)?
varlist  = var (_ "," _ var)*

`expr`  = _ unop _ expr _
      / _ value _ (binop _ expr)* _
unop  = "-" / "#" / "not"
binop = "and" / "or" / ".." / "<=" / ">=" / "~=" / "=="
      / "+" / "-" / "/" / "*" / "^" / "%" / "<" / ">"

`value` = Nil / bool / vararg / number / string
       / tableconstructor / Function
       / functioncall / var
       / "(" _ expr _ ")"
Nil   = "nil" t
bool  = "true" t / "false" t
vararg = "..."
functioncall = prefix (_ suffix &(_ suffix))* _ call
tableconstructor = "{" _ fieldlist* _ "}"
Function = "function" t _ funcbody

var = prefix (_ suffix &(_ suffix))* index
    / symbol


`fieldlist` = field (_ ("," / ";") _ field)*
field = key _ "=" _ val
      / expr
key = "[" expr "]" / symbol
val = expr

`prefix`  = "(" expr ")" / symbol
index   = "[" expr "]" / "." _ symbol
`suffix`  = call / index
`call`    = args / method
method    = ":" _ symbol _ args

args = "(" _ (explist _)? ")" / string
    ;/ tableconstructor
`explist` = expr ("," expr)*

`funcbody` = parameters _ chunk _ "end" t
parameters = "(" _ (symbollist (_ "," _ vararg)*)* ")"
          / "(" _ vararg _ ")"
`symbollist` = (symbol ("," _ symbol)*)


string = singlestring / doublestring / longstring
`singlestring` = "'" ("\\" "'" / (!"'" 1))* "'"
`doublestring` = '"' ('\\' '"' / (!'"' 1))* '"'
;`longstring` = "placeholder"

symbol = reprsymbol
       / !keyword ([A-Z] / [a-z] / "_") ([A-Z] / [a-z] / [0-9] /"_" )*

reprsymbol = "$" ([1-9] [0-9]*)* ("." ([a-z]/[A-Z]))*

number = real / hex / integer
`integer` = [0-9]+
`real` = integer "." integer* (("e" / "E") "-"? integer)?
`hex` = "0" ("x" / "X") higit+ ("." higit*)? (("p" / "P") "-"? higit+)?
`higit` = [0-9] / [a-f] / [A-F]

`_` = comment+ / whitespace
comment = whitespace longcomment
        / whitespace "--" (!"\n" 1)* "\n" whitespace

`longcomment` = "--" longstring
`whitespace` = { \t\n\r}*

keyword = ("and" / "break" / "do" / "else" / "elseif"
        / "end" / "false" / "for" / "function" / "goto" / "if"
        / "in" / "local" / "nil" / "not" / "or" / "repeat"
        / "return" / "then" / "true" / "until" / "while")
        t
`t` = !([A-Z] / [a-z] / [0-9] / "_")
]=]

















local header = [[
local L = require "lpeg"
local C, Cg, Cmt, Cb, P = L.C, L.Cg, L.Cmt, L.Cb, L.P
local equals = P"="^0
local open = "[" * Cg(equals, "init") * "[" * P"\n"^-1
local close = "]" * C(equals) * "]"
local closeeq = Cmt(close * Cb("init"),
                         function (s, i, a, b) return a == b end)

]]








local postscript = [[
  longstring = (open * C((P(1) - closeeq)^0) * close) / 0
]]







local Lua = Node : inherit "lua"

function Lua.__tostring(lua)
   return lua:span()
end

local lua_metas = { lua = Lua }



return Peg(lua_str) : toGrammar(lua_metas, postscript, header)

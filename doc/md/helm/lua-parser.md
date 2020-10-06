# Lua Parser


  The primary purpose of this module is to enable metavariables, for easier
repl interaction\.

Eventually we may wish to replace Lex Luathor with this module\.

This code is an expansion of the [parser in espalier](@br/espalier:espalier/parser), which is intended to demonstrate the PEG
syntax, and shouldn't have non\-standard extensions to the base language\.

Ideally, this would be accomplished through transclusion, but we have quite a
ways to go before transclusion between projects is feasible\.

```lua
local Peg  = require "espalier:espalier/peg"
local Node = require "espalier:espalier/node"
```


### Extended Lua PEG grammar

```peg
lua = shebang* _ chunk _ Error*
shebang = "#" (!"\n" 1)* "\n"
chunk = _ (statement _ ";"?)* (_ laststatement _ ";"?)?

Error = 1+

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

laststatement = "return" t _ (explist)?
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

args = "(" _ (explist _)? ")"
     / string
     / tableconstructor
`explist` = expr ("," expr)*

`funcbody` = parameters _ chunk _ "end" t
parameters = "(" _ (symbollist (_ "," _ vararg)*)* ")"
          / "(" _ vararg _ ")"
`symbollist` = (symbol ("," _ symbol)*)


string = singlestring / doublestring / longstring
`singlestring` = "'" ("\\" "'" / (!"'" !"\n" 1))* "'"
`doublestring` = '"' ('\\' '"' / (!'"' !"\n" 1))* '"'
`longstring`   = ls_open (!ls_close 1)* ls_close

`ls_open` = "[" "="*@eq "["
`ls_close` = "]" "="*@(eq) "]"

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
        / whitespace "--" (!"\n" 1)* whitespace

`longcomment` = "--" longstring
`whitespace` = { \t\n\r}*

keyword = ("and" / "break" / "do" / "else" / "elseif"
        / "end" / "false" / "for" / "function" / "goto" / "if"
        / "in" / "local" / "nil" / "not" / "or" / "repeat"
        / "return" / "then" / "true" / "until" / "while")
        t
`t` = !([A-Z] / [a-z] / [0-9] / "_")
```



## Metatables

```lua

local Lua = Node : inherit "lua"

function Lua.__tostring(lua)
   return lua:span()
end

local lua_metas = { lua = Lua }
```

```lua
return Peg(lua_str) : toGrammar(lua_metas)
```

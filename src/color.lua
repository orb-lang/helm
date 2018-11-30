



















local a = require "anterm"

local core = require "core"

local reflect = require "reflect"

local WIDE_TABLE = 200 -- should be tty-specific

local C = {}

local thread_shade = a.fg24(240, 50, 100)

local function thread_color(str)
   return a.italic .. thread_shade .. str .. a.clear
end

C.color = {}
C.color.number = a.fg(42)
C.color.string = a.fg(222)
C.color.stresc = a.fg(225)
C.color.table  = a.fg(64)
C.color.func   = a.fg24(210,12,120)
C.color.truth  = a.fg(231)
C.color.falsehood  = a.fg(94)
C.color.nilness    = a.fg(93)
C.color.thread     = thread_color
C.color.coro       = thread_color
C.color.field      = a.fg(111)
C.color.userdata   = a.fg24(230, 145, 23)
C.color.cdata      = a.fg24(200, 115, 0)
C.color.metatable  = a.fg24(242, 0, 234)
C.color.meta       = C.color.metatable

C.color["function"] = C.color.func
C.color["true"]     = C.color.truth
C.color["false"]    = C.color.falsehood
C.color["nil"]      = C.color.nilness

C.color.operator = a.fg24(220, 40, 150)
C.color.keyword = a.fg24(100, 210, 100)
C.color.comment = a.fg24(128,128,128)


C.color.alert      = a.fg24(250, 0, 40)
C.color.base       = a.fg24(200, 200, 200)
C.color.search_hl = a.fg24(30, 230, 100)
C.color.error = a.bg24(50,0,0)

C.color.highlight = a.bg24(70, 70, 70)


C.depth = 4 -- table print depth









local no_color = {}
-- if field accessed, pass through
local function _no_c_index(nc, _)
   return nc
end

local function _no_c_call(_, str)
   return str or ""
end

local function _no_c_concat(head, tail)
   head = type(head) == "string" and head or ""
   tail = type(tail) == "string" and tail or ""
   return head .. tail
end

C.no_color = setmetatable({}, { __index  = _no_c_index,
                                __call   = _no_c_call,
                                __concat = _no_c_concat, })











C.color.hints = { field = C.color.field,
                  fn    = C.color.func,
                  mt    = C.color.mt }

local hints = C.color.hints



return C

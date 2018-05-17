















local L = require "lpeg"



local pairs = pairs
local tostring = tostring
local setmetatable = setmetatable
local error = error
local require = require
local rawget = rawget
local io = io
local schar = string.char

local anterm = {}

local CSI = schar(27)..'['

local colormt = {}

local colors = {
    -- attributes
    attribute = {
        reset = 0,
        clear = 0,
        bright = 1,
        bold = 1,
        dim = 2,
        italic = 3,
        underscore = 4,
        blink = 5,
        reverse = 7,
        hidden = 8},
    -- foreground
    fg = {
        black = 30,
        red = 31,
        green = 32,
        yellow = 33,
        blue = 34,
        magenta = 35,
        cyan = 36,
        white = 37,
        clear_fg = 39  },
    -- background
    bg = {
        onblack = 40,
        onred = 41,
        ongreen = 42,
        onyellow = 43,
        onblue = 44,
        onmagenta = 45,
        oncyan = 46,
        onwhite = 47,
        clear_bg = 49}
}

local function makecolor(value, name, kind)
    local color = {
        value = CSI .. value .."m",
        name = name,
        kind = kind }
    return setmetatable(color, colormt)
end

for kind, val in pairs(colors) do
    for c, v in pairs(val) do
        anterm[c] = makecolor(v, c, kind)
    end
end

function colormt:__tostring()
    return self.value
end

function colormt:__concat(other)
    return tostring(self) .. tostring(other)
end

local clear_fg, clear_bg, clear = anterm.clear_fg, anterm.clear_bg,
                                  anterm.clear

local function reset(color)
    -- given a color, reset its action.
    -- simple for fg and bg
    if color.kind == "fg" then
        return clear_fg
    elseif color.kind == "bg" then
        return clear_bg
    elseif color.kind == "attribute" then
        return clear
    end
end

local __ts = colormt.__tostring

function colormt:__call(s)
    if s then
        return __ts(self) .. s .. reset(self)
    else
        return __ts(self)
    end
end










local function byte_panic(byte_p)
       if not byte_p or not (0 <= byte_p and byte_p <= 255) then
        error "xterm value must be 8 bit unsigned"
    end
end

local x256_store = {}

local function ansi_fg(byte)
    local function make (byte)
        byte_panic(byte)
        local color = { value = schar(27).."[38;5;"..byte.."m",
                        kind = "fg" }
        return setmetatable(color, colormt)
    end
    if x256_store[byte] then
        return x256_store[byte]
    else
        local color = make(byte)
        x256_store[byte] = color
        return color
    end
end

local function ansi_bg(byte)
    local function make (byte)
        byte_panic(byte)
        local color = { value = schar(27).."[48;5;"..byte.."m",
                        kind = "bg" }
        return setmetatable(color, colormt)
    end
    if x256_store[byte] then
        return x256_store[byte]
    else
        local color = make(byte)
        x256_store[byte] = color
        return color
    end
end


















local x24k = setmetatable({}, {__mode = "v"})

local fg24pre = schar(27) .. "[38;2;"

local function fg24(r,g,b)
   byte_panic(r)
   byte_panic(g)
   byte_panic(b)
   local color = { value = fg24pre
                           .. r .. ";" .. g .. ";" .. b .. "m",
                   kind = "fg" }
   if x24k[color] then
      return x24k[color]
   end
   x24k[color] = color
   return setmetatable(color, colormt)
end

local bg24pre = schar(27) .. "[48;2;"

local function bg24(r,g,b)
   byte_panic(r)
   byte_panic(g)
   byte_panic(b)
   local color = { value = bg24pre
                           .. r .. ";" .. g .. ";" .. b .. "m",
                   kind = "bg" }
   if x24k[color] then
      return x24k[color]
   end
   x24k[color] = color
   return setmetatable(color, colormt)
end

anterm["fg"], anterm["bg"] = ansi_fg, ansi_bg

anterm["fg24"], anterm["bg24"] = fg24, bg24








local jump = {}

jump.up = function(num)
    if not num then num = "" end
    return CSI..num.."A"
end

jump.down = function(num)
    if not num then num = "" end
        return CSI..num.."B"
end

jump.forward = function(num)
    if not num then num = "" end
    return CSI..num.."C"
end

jump.back = function(num)
    if not num then num = "" end
    return CSI..num.."D"
end

local function Jump(_,row,column)
    return CSI..row..";"..column.."H"
end

local J = { __call = Jump}
setmetatable(jump,J)

anterm["jump"] = jump

function anterm.rc (row, column)
   return CSI .. row .. ";" .. column .. "H"
end

anterm.rowcol = anterm.rc






local erase = {}
anterm.erase = erase

local e__below = CSI .. "0J"
local e__above = CSI .. "1J"
local e__all   = CSI .. "2J"
local e__right = CSI .. "0K"
local e__left  = CSI .. "1K"
local e__line  = CSI .. "2K"

function erase.below() return e__below end

function erase.above() return e__above end

function erase.all()   return e__all   end

function erase.right() return e__right end

function erase.left()  return e__left  end

function erase.line()  return e__line  end







local mouse = {}
anterm.mouse = mouse

function mouse.track(on)
   if on then
      return "\x1b[?1003h"
   else
      return "\x1b[?1003l"
   end
end






function anterm.stash()
   return "\0277"
end

function anterm.pop()
   return "\0278"
end

return anterm

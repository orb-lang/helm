
























































































assert(meta, "must have meta in _G")
assert(write, "must have write in _G")










local color     = require "singletons/color"

local Txtbuf    = require "helm/txtbuf"
local Resbuf    = require "helm/resbuf" -- Not currently used...
local Rainbuf   = require "helm/rainbuf"
local Historian = require "helm/historian"
local Lex       = require "helm/lex"
local Zoneherd  = require "helm/zone"
local repr      = require "helm/repr"

c = color.color

local Nerf   = require "helm/nerf"
local Search = require "helm/search"

local concat               = assert(table.concat)
local sub, gsub, rep, find = assert(string.sub),
                             assert(string.gsub),
                             assert(string.rep),
                             assert(string.find)

local ts = repr.ts




local ModeS = meta()
























ModeS.modes = Nerf





ModeS.REPL_LINE = 2






ModeS.special = {}






function ModeS.default(modeS, category, value)
    return write(ts(value))
end








function ModeS.insert(modeS, category, value)
    local success =  modeS.txtbuf:insert(value)
end







function ModeS.errPrint(modeS, log_stmt)
   modeS.zones.suggest:replace(log_stmt)
   modeS:paint()
   return modeS
end




















local STAT_ICON = "◉ "

local function tf(bool)
   if bool then
      return ts("t", "true")
   else
      return ts("f", "false")
   end
end

local function pr_mouse(m)
   return a.magenta(m.button) .. ": "
      .. a.bright(m.kind) .. " "
      .. tf(m.shift) .. " "
      .. tf(m.meta) .. " "
      .. tf(m.ctrl) .. " "
      .. tf(m.moving) .. " "
      .. tf(m.scrolling) .. " "
      .. a.cyan(m.col) .. "," .. a.cyan(m.row)
end

local function mk_paint(fragment, shade)
   return function(category, action)
      return shade(category .. fragment .. action)
   end
end

local act_map = { MOUSE  = pr_mouse,
                  NAV    = mk_paint(": ", a.italic),
                  CTRL   = mk_paint(": ", c.field),
                  ALT    = mk_paint(": ", a.underscore),
                  ASCII  = mk_paint(": ", c.table),
                  NYI    = mk_paint(": ", a.red)}

local icon_map = { MOUSE = mk_paint(STAT_ICON, c.userdata),
                   NAV   = mk_paint(STAT_ICON, a.magenta),
                   CTRL  = mk_paint(STAT_ICON, a.blue),
                   ALT   = mk_paint(STAT_ICON, c["function"]),
                   ASCII = mk_paint(STAT_ICON, a.green),
                   NYI   = mk_paint(STAT_ICON .. "! ", a.red) }

local function _make_icon(category, value)
   local icon = ""
   local phrase
   if category == "MOUSE" then
      phrase = icon_map[category]("", pr_mouse(value))
   else
      phrase = icon_map[category]("", ts(value))
   end
   return phrase
end











function ModeS.cur_col(modeS)
   return modeS.txtbuf.cursor.col + modeS.l_margin - 1
end






function ModeS.replLine(modeS)
   return modeS.repl_top + #modeS.txtbuf.lines - 1
end







function ModeS.placeCursor(modeS)
   local col = modeS.zones.command.tc + modeS.txtbuf.cursor.col - 1
   local row = modeS.zones.command.tr + modeS.txtbuf.cursor.row - 1
   write(a.colrow(col, row))
end











function ModeS.paint(modeS, all)
   modeS.zones:paint(modeS, all)
   return modeS
end






function ModeS.reflow(modeS)
   modeS.zones:reflow(modeS)
   modeS:paint(true)
end









ModeS.raga = "nerf"
ModeS.raga_default = "nerf"


























ModeS.prompts = { nerf   = "👉 ",
                  search = "⁉️ " }



function ModeS.prompt(modeS)
   modeS.zones.prompt:replace(modeS.prompts[modeS.raga])
end




















ModeS.closet = { nerf = { modes = Nerf,
                          lex   = Lex.lua_thor },
                 search = { modes = Search,
                            lex   = c.base } }

function ModeS.shiftMode(modeS, raga)
   if raga == "search" then
      -- stash current lexer
      -- #todo do this in a less dumb way
      modeS.closet[modeS.raga].lex = modeS.lex
      modeS.lex = modeS.closet.search.lex
      modeS.modes = modeS.closet.search.modes
   elseif raga == "nerf" then
      -- do default nerfy things
      modeS.lex = modeS.closet.nerf.lex
      modeS.modes = modeS.closet.nerf.modes
   elseif raga == "vril-nav" then
      -- do vimmy navigation
   elseif raga == "vril-ins" then
      -- do vimmy inserts
   end
   modeS.raga = raga
   modeS:prompt()
   return modeS
end








local function _firstCharHandler(modeS, category, value)
   local shifted = false
   if category == "ASCII" then
      if value == "/" then
         modeS:shiftMode "search"
         shifted = true
      end
   end
   modeS.firstChar = false
   return shifted
end

















local assertfmt = assert(core.assertfmt)

function ModeS.act(modeS, category, value)
   assertfmt(modeS.modes[category], "no category %s in modeS", category)
   -- catch special handlers first
   if modeS.special[value] then
      return modeS.special[value](modeS, category, value)
   end
   local icon = _make_icon(category, value)
   -- Special first-character handling
   if modeS.firstChar and not (category == "MOUSE" or category == "NAV") then
      modeS.zones.results:replace ""
      local shifted = _firstCharHandler(modeS, category, value)
      if shifted then
        goto final
      end
   end
   -- Dispatch on value if possible
   if type(modeS.modes[category]) == "table"
      and modeS.modes[category][value] then
      modeS.modes[category][value](modeS, category, value)

   -- otherwise fall back:
   elseif category == "ASCII" then
      -- hard coded for now
      modeS:insert(category, value)
   elseif category == "NAV" then
      if modeS.modes.NAV[value] then
         modeS.modes.NAV[value](modeS, category, value)
      else
         icon = _make_icon("NYI", "NAV::" .. value)
      end
   elseif category == "MOUSE" then
      -- do mouse stuff
      if modeS.modes.MOUSE then
         modeS.modes.MOUSE(modeS, category, value)
      end
   else
      icon = _make_icon("NYI", category .. ":" .. value)
   end

   ::final::
   if modeS.raga == "search" then
      -- we need to fake this into a 'result'
      local searchResult = modeS.hist:search(tostring(modeS.txtbuf))
      modeS.zones.results:replace(searchResult)
   end
   -- Replace zones
   modeS.zones.stat_col:replace(icon)
   modeS.zones.command:replace(modeS.txtbuf)
   modeS.zones:adjustCommand()
   modeS:paint()
   collectgarbage()
end





function ModeS.__call(modeS, category, value)
  return modeS:act(category, value)
end
















local function gatherResults(success, ...)
  local n = select('#', ...)
  return success, { n = n, ... }
end



function ModeS.clearResults(modeS)
   write(a.erase.box(1, modeS.repl_top + 1, modeS.r_margin, modeS.max_row))
end



function ModeS.eval(modeS)
   local chunk = tostring(modeS.txtbuf)

   local success, results
   -- first we prefix return
   local f, err = loadstring('return ' .. chunk, 'REPL')

   if not f then
      -- try again without return
      f, err = loadstring(chunk, 'REPL')
   end
   if not f then
      local head = sub(chunk, 1, 1)
      if head == "=" then -- take pity on old-school Lua hackers
         f, err = loadstring('return ' .. sub(chunk,2), 'REPL')
      end -- more special REPL prefix soon: /, ?, >(?)
   end
   if f then
      setfenv(f, _G)
      success, results = gatherResults(xpcall(f, debug.traceback))
      if not success and string.find(results[1], "is not declared") then
         -- let's try it with __G
         setfenv(f, __G)
         success, results = gatherResults(xpcall(f, debug.traceback))
      end
      if success then
         -- successful call
         if results.n > 0 then
            local rb = Rainbuf(results)
            modeS.zones.results:replace(rb)
         else
            modeS.zones.results:replace ""
         end
      else
         -- error
         results.frozen = true
         modeS.zones.results:replace(results)
      end
   else
      if err:match "'<eof>'$" then
         -- Lua expects some more input, advance the txtbuf
         modeS.txtbuf:advance()
         write(a.colrow(1, modeS.repl_top + 1) .. "...")
         return true
      else
         local to_err = { err.. "\n" .. debug.traceback(),
                          n = 1,
                          frozen = true}
         modeS.zones.results:replace(to_err)
         -- pass through to default.
      end
   end

   modeS.hist:append(modeS.txtbuf, results, success)
   modeS.hist.cursor = #modeS.hist
   -- modeS:prompt()
end







local function _status__repr(status_table)
  return table.concat(status_table)
end

local _stat_M = meta {}
_stat_M.__repr = _status__repr

function _stat_M.clear(status_table)
  return setmeta({}, getmeta(status_table))
end







function new(max_col, max_row)
  local modeS = meta(ModeS)
  modeS.txtbuf = Txtbuf()
  modeS.hist  = Historian()
  modeS.status = setmeta({}, _stat_M)
  rawset(__G, "stat", modeS.status)
  modeS.lex  = Lex.lua_thor
  modeS.hist.cursor = #modeS.hist + 1
  modeS.max_col = max_col
  modeS.max_row = max_row
  -- this will be replaced with Zones
  modeS.l_margin = 4
  modeS.r_margin = 80
  modeS.row = 2
  modeS.repl_top  = ModeS.REPL_LINE
  modeS.zones = Zoneherd(modeS, write)
  modeS.zones.status:replace "an repl, plz reply uwu 👀"
  modeS.zones.prompt:replace "👉  "
  -- initial state
  modeS.firstChar = true
  return modeS
end

ModeS.idEst = new



return new


























































































assert(meta, "must have meta in _G")
assert(write, "must have write in _G")
assert(ts, "must have ts in _G")










local stacktrace = require "stacktrace" . stacktrace

local Txtbuf    = require "txtbuf"
local Resbuf    = require "resbuf" -- Not currently used...
local Historian = require "historian"
local Lex       = require "lex"

local Nerf   = require "nerf"
local Search = require "search"

local concat         = assert(table.concat)
local sub, gsub, rep = assert(string.sub),
                       assert(string.gsub),
                       assert(string.rep)



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
   if category == "MOUSE" then
      phrase = icon_map[category]("", pr_mouse(value))
   else
      phrase = icon_map[category]("", ts(value))
   end
   return phrase
end







function ModeS.cur_col(modeS)
   return modeS.txtbuf.cursor + modeS.l_margin - 1
end

-- This method needs to live on a zone-by-zone basis,
-- and can even be pre-calculated and cached
function ModeS.nl(modeS)
   write(a.col(modeS.l_margin).. a.jump.down(1))
end








local lines = assert(string.lines, "string.lines must be provided")

function ModeS.writeResults(modeS, str)
   local nl = a.col(modeS.l_margin) .. a.jump.down(1)
   local pr_row = modeS:replLine() + 1
   write(a.cursor.hide())
   for line in lines(str) do
       write(line)
       write(nl)
       pr_row = pr_row + 1
       if pr_row > modeS.max_row then
          break
       end
   end
   write(a.cursor.show())
end



function ModeS.replLine(modeS)
   return modeS.repl_top + #modeS.txtbuf.lines - 1
end



function ModeS.printResults(modeS, results, new)
   local rainbuf = {}
   write(a.cursor.hide())
   modeS:clearResults()
   local row = new and modeS.repl_top or modeS:replLine()
   modeS:writeResults(a.rc(row, modeS.l_margin))
   for i = 1, results.n do
      if results.frozen then
         rainbuf[i] = results[i]
      else
         local catch_val = ts(results[i])
         if type(catch_val) == 'string' then
            rainbuf[i] = catch_val
         else
            error("ts returned a " .. type(catch_val) .. "in printResults")
         end
      end
   end
   modeS:writeResults(concat(rainbuf, '   '))
   write(a.cursor.show())
end








function ModeS.paint(modeS)
   modeS.zones:paint(modeS)
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
      else
         modeS.firstChar = false
      end
    end
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
   if modeS.firstChar and not (category == "MOUSE") then
      modeS:clearResults()
      local shifted = _firstCharHandler(modeS, category, value)
      if shifted then
        modeS:paint()
        return modeS:paint_txtbuf()
      end
   end
   -- Dispatch on value if possible
   if modeS.modes[category][value] then
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
   else
      icon = _make_icon("NYI", category .. ":" .. value)
   end
   -- Hack in painting and searching
   if modeS.raga == "search" then
      -- we need to fake this into a 'result'
      local searchResult = {}
      searchResult[1] = modeS.hist:search(tostring(modeS.txtbuf))
      searchResult.n = 1
      modeS:printResults(searchResult, false)
   end
   -- Replace zones
   modeS.zones.stat_col:replace(icon)
   modeS.zones.command:replace(modeS.txtbuf)
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
   write(a.erase.box(modeS.repl_top + 1, 1, modeS.max_row, modeS.r_margin))
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
      success, results = gatherResults(xpcall(f, stacktrace))
      if success then
      -- successful call
         if results.n > 0 and not modeS.zones.painted then
            modeS:printResults(results)
         else
            modeS:clearResults()
         end
      else
      -- error
         write(a.cursor.hide())
         modeS:clearResults()
         modeS:writeResults(results[1])
      end
   else
      if err:match "'<eof>'$" then
         -- Lua expects some more input, advance the txtbuf
         modeS.txtbuf:advance()
         modeS.zones:adjust(modeS.zones.command, {0, 1}, true)
         write(a.col(1) .. "...")
         return true
      else
         modeS:clearResults()
         modeS:writeResults(err .. "\n" .. stacktrace())
         -- pass through to default.
      end
   end

   modeS.hist:append(modeS.txtbuf, results, success)
   modeS.hist.cursor = #modeS.hist
   if success then modeS.hist.results[modeS.txtbuf] = results end
   modeS:prompt()
end








function new(max_col, max_row)
  local modeS = meta(ModeS)
  modeS.txtbuf = Txtbuf()
  modeS.hist  = Historian()
  modeS.lex  = Lex.lua_thor
  modeS.hist.cursor = #modeS.hist + 1
  modeS.max_col = max_col
  modeS.max_row = max_row
  -- this will be replaced with Zones
  modeS.l_margin = 4
  modeS.r_margin = 80
  modeS.row = 2
  modeS.repl_top  = ModeS.REPL_LINE
  -- initial state
  modeS.firstChar = true
  return modeS
end

ModeS.idEst = new



return new

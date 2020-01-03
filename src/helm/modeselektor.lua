
























































































assert(meta, "must have meta in _G")
assert(write, "must have write in _G")










local c = (require "singletons/color").color

local Txtbuf     = require "helm/txtbuf"
local Resbuf     = require "helm/resbuf" -- Not currently used...
local Rainbuf    = require "helm/rainbuf"
local Historian  = require "helm/historian"
local Lex        = require "helm/lex"
local Zoneherd   = require "helm/zone"
local repr       = require "helm/repr"
local lua_parser = require "helm/lua-parser"

local names     = require "helm/repr/names"

local Nerf      = require "helm/nerf"
local Search    = require "helm/search"

local concat               = assert(table.concat)
local sub, gsub, rep, find = assert(string.sub),
                             assert(string.gsub),
                             assert(string.rep),
                             assert(string.find)

local ts = repr.ts_color




local ModeS = meta()
























ModeS.modes = Nerf





ModeS.REPL_LINE = 2






ModeS.special = {}








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
  return bool and c["true"]("t") or c["false"]("f")
end

local function mouse_paint(m)
   return c.userdata(STAT_ICON)
      .. a.magenta(m.button) .. ": "
      .. a.bright(m.kind) .. " "
      .. tf(m.shift) .. " "
      .. tf(m.meta) .. " "
      .. tf(m.ctrl) .. " "
      .. tf(m.moving) .. " "
      .. tf(m.scrolling) .. " "
      .. a.cyan(m.col) .. "," .. a.cyan(m.row)
end

local function mk_paint(fragment, shade)
   return function(action)
      return shade(fragment .. action)
   end
end

local function paste_paint(frag)
   local result
   -- #todo handle escaping of special characters in pasted data
   if #frag < 20 then
      result = "PASTE: " .. frag
   else
      result = ("PASTE(%d): %s..."):format(#frag, frag:sub(1, 17))
   end
   return a.green(STAT_ICON .. result)
end

local icon_map = { MOUSE = mouse_paint,
                   NAV   = mk_paint(STAT_ICON, a.magenta),
                   CTRL  = mk_paint(STAT_ICON, a.blue),
                   ALT   = mk_paint(STAT_ICON, c["function"]),
                   ASCII = mk_paint(STAT_ICON, a.green),
                   UTF8  = mk_paint(STAT_ICON, a.green),
                   PASTE = paste_paint,
                   NYI   = mk_paint(STAT_ICON .. "! ", a.red) }

local function _make_icon(category, value)
   return icon_map[category](value)
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














local assertfmt, iscallable = assert(core.assertfmt), assert(core.iscallable)

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
   -- Or on category if the whole category is callable
   elseif iscallable(modeS.modes[category]) then
      modeS.modes[category](modeS, category, value)
   -- Default behavior for inserts:
   elseif category == "ASCII"
      or category == "UTF8" then
      modeS:insert(category, value)
   elseif category == "PASTE" then
      modeS.txtbuf:paste(value)
   -- Otherwise display the unknown command
   else
      icon = _make_icon("NYI", category .. ":" .. value)
   end

   ::final::
   if modeS.raga == "search" then
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



















local eval_ENV = {}
local eval_M = {}
setmeta(eval_ENV, eval_M)


local function indexer(Env, key)
   return Env[key]
end

function eval_M.__index(eval_ENV, key)
   local ok, value = pcall(indexer, _G, key)
   if ok and value ~= nil then
      return value
   end
   ok, value = pcall(indexer, __G, key)
   if ok and value ~= nil then
      return value
   end
   return nil
end

local function newindexer(Env, key, value)
   Env[key] = value
end

local addName = assert(names.addName)

function eval_M.__newindex(eval_ENV, key, value)
   local ok = pcall(newindexer, _G, key, value)
   if not ok then
      rawset(_G, key, value)
   end
   addName { [key] = value }
end



local function gatherResults(success, ...)
  local n = select('#', ...)
  return success, { n = n, ... }
end



local result_repr_M = meta {}

function result_repr_M.__repr(result)
  local i = 1
  return function()
     if i <= #result then
       i = i + 1
       return result[i - 1]
     end
  end
end



local insert = assert(table.insert)

function ModeS.eval(modeS)
   local chunk = tostring(modeS.txtbuf)
   -- check for leading =, old-school style
   local head = sub(chunk, 1, 1)
   if head == "=" then -- take pity on old-school Lua hackers
       chunk = "return " .. sub(chunk,2)
   end
   -- add "return" and see if it parses
   local return_chunk = "return " .. chunk
   local parsed_chunk = lua_parser(return_chunk)
   if not parsed_chunk:select "Error" () then
      chunk = return_chunk
   else
      -- re-parse the chunk
      parsed_chunk = lua_parser(chunk)
   end
   -- #Todo tinker with the chunk, finding $1-type vars
   local success, results
   local f, err = loadstring(chunk, 'REPL')
   if f then
      setfenv(f, eval_ENV)
      success, results = gatherResults(xpcall(f, debug.traceback))
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
         local to_err = { err,
                          n = 1,
                          frozen = true}
         modeS.zones.results:replace(to_err)
         -- pass through to default.
      end
   end

   modeS.hist:append(modeS.txtbuf, results, success)
   local line_id = modeS.hist.line_ids[modeS.hist.n]
   if success then
      -- async render of resbuf
      -- set up closed-over state
      local lineGens, result_tostring = {}, {n = results.n}
      for i = 1, results.n do
         -- create line generators for each result
         lineGens[i] = repr.lineGen(results[i], modeS.zones.results:width())
         result_tostring[i] = setmeta({}, result_repr_M)
      end
      local i = 1
      local result_idler = uv.new_idle()
      -- run string generator as idle process
      result_idler:start(function()
         while i <= results.n do
            local line = lineGens[i]()
            if line then
               insert(result_tostring[i],line)
               return nil
            else
               i = i + 1
               return nil
            end
         end
         result_idler:stop()
      end)
      modeS.hist.result_buffer[modeS.hist.n] = result_tostring
   end
   modeS.hist.cursor = modeS.hist.n
end







local function _status__repr(status_table)
  return concat(status_table)
end

local _stat_M = meta {}
_stat_M.__repr = _status__repr

function _stat_M.clear(status_table)
  return setmeta({}, getmeta(status_table))
end







local function new(max_col, max_row)
  local modeS = meta(ModeS)
  modeS.txtbuf = Txtbuf()
  modeS.hist  = Historian()
  modeS.status = setmeta({}, _stat_M)
  rawset(__G, "stat", modeS.status)
  modeS.lex  = Lex.lua_thor
  modeS.hist.cursor = modeS.hist.n + 1
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

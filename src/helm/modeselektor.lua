
























































































assert(meta, "must have meta in _G")
assert(write, "must have write in _G")










local c = import("singletons/color", "color")

local Txtbuf     = require "helm/txtbuf"
local Resbuf     = require "helm/resbuf" -- Not currently used...
local Rainbuf    = require "helm/rainbuf"
local Historian  = require "helm/historian"
local Lex        = require "helm/lex"
local Zoneherd   = require "helm/zone"
local Suggest    = require "helm/suggest"
local repr       = require "helm/repr"
local lua_parser = require "helm/lua-parser"

local Nerf      = require "helm/raga/nerf"
local Search    = require "helm/raga/search"
local Complete  = require "helm/raga/complete"

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







function ModeS.placeCursor(modeS)
   local col = modeS.zones.command.tc + modeS.txtbuf.cursor.col - 1
   local row = modeS.zones.command.tr + modeS.txtbuf.cursor.row - 1
   write(a.colrow(col, row))
end







function ModeS.paint(modeS)
   modeS.zones:paint(modeS)
   return modeS
end






function ModeS.reflow(modeS)
   modeS.zones:reflow(modeS)
   modeS:paint()
   return modeS
end









ModeS.raga_default = "nerf"


























function ModeS.continuationLines(modeS)
   return modeS.txtbuf and #modeS.txtbuf.lines - 1 or 0
end







function ModeS.updatePrompt(modeS)
   local prompt = modeS.modes.prompt_char .. " " .. ("\n..."):rep(modeS:continuationLines())
   modeS.zones.prompt:replace(prompt)
end




















ModeS.closet = { nerf =     { modes = Nerf,
                              lex   = Lex.lua_thor },
                 search =   { modes = Search,
                              lex   = Lex.null },
                 complete = { modes = Complete,
                              lex   = Lex.lua_thor } }

function ModeS.shiftMode(modeS, raga)
   if raga == "search" then
      -- stash current lexer
      -- #todo do this in a less dumb way
      modeS.closet[modeS.raga].lex = modeS.lex
   end
   modeS.lex = modeS.closet[raga].lex
   modeS.modes = modeS.closet[raga].modes
   modeS.raga = raga
   modeS:updatePrompt()
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














local assertfmt, iscallable = import("core/string", "assertfmt"),
                              import("core/table", "iscallable")

function ModeS.act(modeS, category, value)
   assertfmt(modeS.modes[category], "no category %s in modeS", category)
   -- catch special handlers first
   if modeS.special[value] then
      return modeS.special[value](modeS, category, value)
   end
   local icon = _make_icon(category, value)
   -- Special first-character handling
   if modeS.firstChar and not (category == "MOUSE" or category == "NAV") then
      modeS:setResults ""
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
   -- Otherwise display the unknown command
   else
      local val_rep = string.format("%q",value):sub(2,-2)
      icon = _make_icon("NYI", category .. ": " .. val_rep)
   end

   ::final::
   if modeS.raga == "search" then
      local searchResult = modeS.hist:search(tostring(modeS.txtbuf))
      modeS:setResults(searchResult)
   end
   -- Replace zones
   modeS.zones.stat_col:replace(icon)
   modeS.zones.command:replace(modeS.txtbuf)
   modeS:updatePrompt()
   modeS.suggest:update(modeS, category, value)
   -- Reflow in case command height has changed. Includes a paint.
   modeS:reflow()
   collectgarbage()
end





function ModeS.__call(modeS, category, value)
  return modeS:act(category, value)
end








local instanceof = import("core/meta", "instanceof")

function ModeS.setResults(modeS, results)
   results = results or ""
   if results == "" then
      modeS.zones.results:replace(results)
      return
   end
   if type(results) == "string" then
      results = { results, n = 1, frozen = true }
   end
   local rb = instanceof(results, Rainbuf) and results or Rainbuf(results)
   rb.scrollable = true
   modeS.zones.results:replace(rb)
end


















local eval_ENV = {}
local eval_M = {}
setmetatable(eval_ENV, eval_M)


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

local loadNames = import("helm/repr/names", "loadNames")

function eval_M.__newindex(eval_ENV, key, value)
   local ok = pcall(newindexer, _G, key, value)
   if not ok then
      rawset(_G, key, value)
   end
   -- Use loadNames() to get the key added to all_symbols
   -- Should really divide up responsibility better between
   -- loadNames() and addName()
   loadNames{ [key] = value }
end



local function gatherResults(success, ...)
  return success, pack(...)
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

function ModeS.__eval(modeS, chunk, no_append)
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
      if not success then
         -- error
         results.frozen = true
      end
   else
      if err:match "'<eof>'$" then
         -- Lua expects some more input, advance the txtbuf
         modeS.txtbuf:advance()
         write(a.colrow(1, modeS.repl_top + 1) .. "...")
         return true
      else
         -- make the error into the result
         results = { err,
                     n = 1,
                     frozen = true }
      end
   end
   if not no_append then
      modeS:setResults(results)
      modeS.hist:append(modeS.txtbuf, results, success)
      if success then
         -- async render of resbuf
         -- set up closed-over state
         local lineGens, result_tostring = {}, {n = results.n}
         for i = 1, results.n do
            -- create line generators for each result
            lineGens[i] = repr.lineGen(results[i], modeS.zones.results:width())
            result_tostring[i] = setmetatable({}, result_repr_M)
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
end

function ModeS.eval(modeS)
   modeS:__eval(tostring(modeS.txtbuf))
end







local function _status__repr(status_table)
  return concat(status_table)
end

local _stat_M = meta {}
_stat_M.__repr = _status__repr

function _stat_M.clear(status_table)
  return setmetatable({}, getmetatable(status_table))
end







local function new(max_col, max_row)
  local modeS = meta(ModeS)
  modeS.txtbuf = Txtbuf()
  modeS.hist  = Historian()
  modeS.suggest = Suggest()
  modeS.status = setmetatable({}, _stat_M)
  rawset(__G, "stat", modeS.status)
  modeS.max_col = max_col
  modeS.max_row = max_row
  -- this will be replaced with Zones
  modeS.l_margin = 4
  modeS.r_margin = 80
  modeS.repl_top = ModeS.REPL_LINE
  modeS.zones = Zoneherd(modeS, write)
  modeS.zones.status:replace "an repl, plz reply uwu 👀"
  -- initial state
  modeS.firstChar = true
  modeS:shiftMode(modeS.raga_default)
  return modeS
end

ModeS.idEst = new



return new

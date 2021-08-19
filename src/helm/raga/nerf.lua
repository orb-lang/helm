

















assert(meta, "must have meta in _G")



local a         = require "anterm:anterm"
local Txtbuf    = require "helm:buf/txtbuf"
local Rainbuf   = require "helm:buf/rainbuf"
local Historian = require "helm/historian"
local Lex       = require "helm/lex"

local concat, insert = assert(table.concat), assert(table.insert)
local sub, gsub, rep = assert(string.sub),
                       assert(string.gsub),
                       assert(string.rep)






local clone    = import("core/table", "clone")
local EditBase = require "helm:helm/raga/edit"

local Nerf = clone(EditBase, 2)
Nerf.name = "nerf"
Nerf.prompt_char = "👉"






local function _insert(modeS, category, value)
   if modeS:agent'edit':contents() == "" then
      modeS:clearResults()
      if value == "/" then
         modeS.shift_to = "search"
         return
      end
      if value == "?" then
         modeS:openHelp()
         return
      end
   end
   modeS:agent'edit':insert(value)
end

Nerf.ASCII = _insert
Nerf.UTF8 = _insert







local NAV = Nerf.NAV

local function _prev(modeS)
   -- Save what the user is currently typing...
   local linestash = modeS:agent'edit':contents()
   -- ...but only if they're at the end of the history,
   -- and obviously only if there's anything there
   if linestash == "" or modeS.hist.cursor <= modeS.hist.n then
      linestash = nil
   end
   local prev_line, prev_result = modeS.hist:prev()
   if linestash then
      modeS.hist:append(linestash)
   end
   modeS:agent'edit':update(prev_line)
   modeS:setResults(prev_result)
   return modeS
end

function NAV.UP(modeS, category, value)
   local inline = modeS:agent'edit':up()
   if not inline then
      _prev(modeS)
   end
   return modeS
end

local function _advance(modeS)
   local new_line, next_result = modeS.hist:next()
   if not new_line then
      local added = modeS.hist:append(modeS:agent'edit':contents())
      if added then
         modeS.hist.cursor = modeS.hist.n + 1
      end
   end
   modeS:agent'edit':update(new_line)
   modeS:setResults(next_result)
   return modeS
end

function NAV.DOWN(modeS, category, value)
   local inline = modeS:agent'edit':down()
   if not inline then
      _advance(modeS)
   end

   return modeS
end



function _eval(modeS)
   local line = modeS:agent'edit':contents()
   local success, results = modeS.eval(line)
   if not success and results == 'advance' then
      modeS:agent'edit':endOfText()
      modeS:agent'edit':nl()
   else
      modeS.hist:append(line, results, success)
      modeS.hist.cursor = modeS.hist.n + 1
      modeS:setResults(results)
      modeS:agent'edit':clear()
   end
end

function NAV.RETURN(modeS, category, value)
   if modeS:agent'edit':shouldEvaluate() then
      _eval(modeS)
   else
      modeS:agent'edit':nl()
   end
end

function NAV.CTRL_RETURN(modeS, category, value)
   _eval(modeS)
end

function NAV.SHIFT_RETURN(modeS, category, value)
   modeS:agent'edit':nl()
end

-- Add aliases for terminals not in CSI u mode
Nerf.CTRL["^\\"] = NAV.CTRL_RETURN
NAV.ALT_RETURN = NAV.SHIFT_RETURN

local function _activateCompletion(modeS)
   if modeS:agent'suggest'.last_collection then
      modeS.shift_to = "complete"
      return true
   else
      return false
   end
end

function NAV.SHIFT_DOWN(modeS, category, value)
   if not _activateCompletion(modeS) then
      modeS:agent'results':scrollDown()
   end
end

function NAV.SHIFT_UP(modeS, category, value)
   if not _activateCompletion(modeS) then
      modeS:agent'results':scrollUp()
   end
end

function NAV.TAB(modeS, category, value)
   if not _activateCompletion(modeS) then
      modeS:agent'edit':paste("   ")
   end
end

function NAV.SHIFT_TAB(modeS, category, value)
   -- If we can't activate completion, nothing to do really
   _activateCompletion(modeS)
end






Nerf.default_keymaps = clone(EditBase.default_keymaps)









insert(Nerf.default_keymaps, {
   ["C-b"] = "left",
   ["C-f"] = "right",
   ["C-n"] = "down",
   ["C-p"] = "up"
})






function Nerf.scrollResultsUp(maestro, event)
   maestro.agents.results:scrollUp(event.num_lines)
end

function Nerf.scrollResultsDown(maestro, event)
   maestro.agents.results:scrollDown(event.num_lines)
end

insert(Nerf.default_keymaps, {
   SCROLL_UP = "scrollResultsUp",
   SCROLL_DOWN = "scrollResultsDown"
})






local ALT = Nerf.ALT






ALT ["M-e"] = function(modeS, category, value)
   local top = modeS.hist.n
   local cursor = modeS.hist.cursor
   for i = cursor, top do
      -- Discard the second return value from :index
      -- or it will confuse the Txtbuf constructor rather badly
      local line = modeS.hist:index(i)
      modeS:agent'edit':update(line)
      _eval(modeS)
   end
end








function Nerf.onCursorChanged(modeS)
   modeS:agent'suggest':update()
   EditBase.onCursorChanged(modeS)
end

function Nerf.onTxtbufChanged(modeS)
   modeS:agent'suggest':update()
   EditBase.onTxtbufChanged(modeS)
end










local Resbuf = require "helm:buf/resbuf"
function Nerf.onShift(modeS)
   EditBase.onShift(modeS)
   modeS:bindZone("results", "results", Resbuf, { scrollable = true })
   local txtbuf = modeS.zones.command.contents
   txtbuf.suggestions = modeS:agent'suggest':window()
end



return Nerf


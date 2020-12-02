












local Rainbuf = require "helm:rainbuf"
local Resbuf  = require "helm:resbuf"
local Txtbuf  = require "helm:txtbuf"

local Sessionbuf = Rainbuf:inherit()






-- The (maximum) number of rows we will use for the "line" (command)
-- (in case it is many lines long)
Sessionbuf.ROWS_PER_LINE = 4
-- The (maximum) number of rows we will use for the result of the selected line
Sessionbuf.ROWS_PER_RESULT = 7

















local clamp = assert(require "core:math" . clamp)
function Sessionbuf.selectIndex(buf, index)
   index = clamp(index, 1, #buf.session)
   if index ~= buf.selected_index then
      buf.selected_index = index
      local premise = buf:selectedPremise()
      -- #todo re-evaluate sessions on -s startup, and display an
      -- indication of whether there are changes (and eventually a diff)
      -- rather than just the newest available result
      buf.resbuf:replace(premise.new_result or premise.old_result)
      return true
   end
   return false
end

-- #todo ugh, need the metatable, have the constructor
local SelectionList = getmetatable(require "helm:selection_list" ())
Sessionbuf.selectNext = SelectionList.selectNext
Sessionbuf.selectPrevious = SelectionList.selectPrevious
Sessionbuf.selectFirst = SelectionList.selectFirst








function Sessionbuf.scrollResultsDown(buf)
   local offset = buf.resbuf.offset + 1
   buf.resbuf:composeUpTo(offset + buf.ROWS_PER_RESULT)
   offset = clamp(offset, 0, #buf.resbuf.lines - buf.ROWS_PER_RESULT)
   if offset ~= buf.resbuf.offset then
      buf.resbuf.offset = offset
      return true
   end
   return false
end

function Sessionbuf.scrollResultsUp(buf)
   if buf.resbuf.offset > 0 then
      buf.resbuf.offset = buf.resbuf.offset - 1
      return true
   end
   return false
end






function Sessionbuf.selectedPremise(buf)
   return buf.session[buf.selected_index]
end












local status_cycle_map = {
   accept = "reject",
   reject = "ignore",
   ignore = "skip",
   skip   = "accept"
}
function Sessionbuf.toggleSelectedState(buf)
   local premise = buf.session[buf.selected_index]
   premise.status = status_cycle_map[premise.status]
   return true
end













function Sessionbuf.clearCaches(buf)
   buf:super"clearCaches"()
   buf._composeOneLine = nil
end






local wrap = assert(coroutine.wrap)
function Sessionbuf.initComposition(buf, cols)
   buf:super"initComposition"(cols)
   buf._composeOneLine = wrap(function() buf:_composeAll() end)
end










local status_icons = {
   accept = "✅",
   reject = "❌",
   ignore = "🟡",
   skip   = "🚫"
}

local box_light = assert(require "anterm:box" . light)
local yield = assert(coroutine.yield)
local c = assert(require "singletons:color" . color)
function Sessionbuf._composeAll(buf)
   local inner_cols = buf.cols - 2 -- For the box borders
   for i, premise in ipairs(buf.session) do
      yield(i == 1
         and box_light:topLine(inner_cols)
         or box_light:spanningLine(inner_cols))
      -- Render the line (which could actually be multiple physical lines)
      -- Leave 4 columns on the left for the status icon,
      -- and one on the right for padding
      local line_prefix = box_light:contentLine(inner_cols) ..
         status_icons[premise.status] .. ' '
      for line in buf.txtbufs[i]:lineGen(buf.ROWS_PER_LINE, inner_cols - 5) do
         -- Selected premise gets a highlight
         if i == buf.selected_index then
            line = c.highlight(line)
         end
         yield(line_prefix .. line)
         line_prefix = box_light:contentLine(inner_cols) .. '   '
      end
      -- Selected premise also displays results
      if i == buf.selected_index then
         yield(box_light:spanningLine(inner_cols))
         -- No need for left padding inside the box, the Rainbuf has a
         -- 3-column gutter anyway. Do want to leave 1 column of right padding
         for line in buf.resbuf:lineGen(buf.ROWS_PER_RESULT, inner_cols - 1) do
            yield(box_light:contentLine(inner_cols) .. line)
         end
      end
   end
   yield(box_light:bottomLine(inner_cols))
   buf._composeOneLine = nil
end








function Sessionbuf._init(buf)
   buf:super"_init"()
   buf.live = true
   buf.resbuf = Resbuf({ n = 0 }, { scrollable = true })
   buf.txtbufs = {}
end






local lua_thor = assert(require "helm:lex" . lua_thor)
function Sessionbuf.replace(buf, session)
   buf:super"replace"(session)
   buf.session = session
   for i, premise in ipairs(session) do
      if buf.txtbufs[i] then
         buf.txtbufs[i]:replace(premise.line)
      else
         buf.txtbufs[i] = Txtbuf(premise.line, { lex = lua_thor })
      end
   end
   for i = #session + 1, #buf.txtbufs do
      buf.txtbufs[i] = nil
   end
   buf:selectFirst()
end



local Sessionbuf_class = setmetatable({}, Sessionbuf)
Sessionbuf.idEst = Sessionbuf_class

return Sessionbuf_class


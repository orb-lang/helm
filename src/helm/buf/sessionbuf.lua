












local Rainbuf = require "helm:buf/rainbuf"
local Resbuf  = require "helm:buf/resbuf"
local Txtbuf  = require "helm:buf/txtbuf"

local Sessionbuf = Rainbuf:inherit()






-- The (maximum) number of rows we will use for the "line" (command)
-- (in case it is many lines long)
Sessionbuf.ROWS_PER_LINE = 4
-- The (maximum) number of rows we will use for the result of the selected line
Sessionbuf.ROWS_PER_RESULT = 7

















local clamp = assert(require "core:math" . clamp)
function Sessionbuf.selectIndex(buf, index)
   index = #buf.value == 0
      and 0
      or clamp(index, 1, #buf.value)
   if index ~= buf.selected_index then
      buf.selected_index = index
      local premise = buf:selectedPremise()
      local result
      if premise then
         -- #todo re-evaluate sessions on -s startup, and display an
         -- indication of whether there are changes (and eventually a diff)
         -- rather than just the newest available result
         result = premise.new_result or premise.old_result
      end
      buf.resbuf:replace(result)
      buf.resbuf.offset = 0
      return true
   end
   return false
end









function Sessionbuf.selectNextWrap(buf)
   local new_idx = buf.selected_index < #buf.value
      and buf.selected_index + 1
      or 1
   return buf:selectIndex(new_idx)
end
function Sessionbuf.selectPreviousWrap(buf)
   local new_idx = buf.selected_index > 1
      and buf.selected_index - 1
      or #buf.value
   return buf:selectIndex(new_idx)
end










function Sessionbuf.rowsForSelectedResult(buf)
   buf.resbuf:initComposition(buf.cols - 3)
   buf.resbuf:composeUpTo(buf.ROWS_PER_RESULT)
   return clamp(#buf.resbuf.lines, 0, buf.ROWS_PER_RESULT)
end








local gsub = assert(string.gsub)
function Sessionbuf.positionOf(buf, index)
   local position = 1
   for i = 1, index - 1 do
      local num_lines = select(2, gsub(buf.value[i].line, '\n', '\n')) + 1
      num_lines = clamp(num_lines, 1, buf.ROWS_PER_LINE)
      position = position + num_lines + 1
      if i == buf.selected_index then
         position = position + buf:rowsForSelectedResult() + 1
      end
   end
   return position
end

function Sessionbuf.positionOfSelected(buf)
   return buf:positionOf(buf.selected_index)
end








function Sessionbuf.scrollResultsDown(buf)
   -- #todo this should all be handled internally by Rainbuf--
   -- we should just be calling buf.resbuf:scrollDown()
   local offset = buf.resbuf.offset + 1
   buf.resbuf:composeUpTo(offset + buf.ROWS_PER_RESULT)
   local max_offset = clamp(#buf.resbuf.lines - buf.ROWS_PER_RESULT, 0)
   offset = clamp(offset, 0, max_offset)
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
   return buf.value[buf.selected_index]
end












local status_cycle_map = {
   ignore = "accept",
   accept = "reject",
   reject = "skip",
   skip   = "ignore"
}

function Sessionbuf.toggleSelectedState(buf)
   local premise = buf:selectedPremise()
   premise.status = status_cycle_map[premise.status]
   return true
end

local inverse = assert(require "core:table" . inverse)
local status_reverse_map = inverse(status_cycle_map)

function Sessionbuf.reverseToggleSelectedState(buf)
   local premise = buf:selectedPremise()
   premise.status = status_reverse_map[premise.status]
   return true
end












local function _swapPremises(buf, index_a, index_b)
   local premise_a = buf.value[index_a]
   local premise_b = buf.value[index_b]
   buf.value[index_a] = premise_b
   buf.txtbufs[index_a]:replace(premise_b.line)
   premise_b.ordinal = index_a
   buf.value[index_b] = premise_a
   buf.txtbufs[index_b]:replace(premise_a.line)
   premise_a.ordinal = index_b
   buf:clearCaches()
end

function Sessionbuf.movePremiseUp(buf)
   if buf.selected_index == 1 then
      return false
   end
   _swapPremises(buf, buf.selected_index, buf.selected_index - 1)
   -- Maintain selection of the same premise after the move
   -- Will never wrap because we disallowed moving the first premise up
   buf:selectPreviousWrap()
   return true
end

function Sessionbuf.movePremiseDown(buf)
   if buf.selected_index == #buf.value then
      return false
   end
   _swapPremises(buf, buf.selected_index, buf.selected_index + 1)
   buf:selectNextWrap()
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
   ignore = "🟡",
   accept = "✅",
   reject = "🚫",
   skip   = "🗑 "
}

local box_light = assert(require "anterm:box" . light)
local yield = assert(coroutine.yield)
local c = assert(require "singletons:color" . color)
function Sessionbuf._composeAll(buf)
   local inner_cols = buf.cols - 2 -- For the box borders
   for i, premise in ipairs(buf.value) do
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
         -- Account for left and right padding inside the box
         for line in buf.resbuf:lineGen(buf.ROWS_PER_RESULT, inner_cols - 2) do
            yield(box_light:contentLine(inner_cols) .. line)
         end
      end
   end
   if #buf.value == 0 then
      yield(box_light:topLine(inner_cols))
      yield(box_light:contentLine(inner_cols) .. "No premises to display")
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
   buf:selectIndex(1)
end



local Sessionbuf_class = setmetatable({}, Sessionbuf)
Sessionbuf.idEst = Sessionbuf_class

return Sessionbuf_class


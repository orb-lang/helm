











local cluster = require "cluster:cluster"
local Agent = require "helm:agent/agent"

local math = core.math
local string = core.string
local table = core.table
local lines = assert(string.lines)
local concat, insert = assert(table.concat), assert(table.insert)
local Codepoints = require "singletons:codepoints"
local Point = require "anterm:point"

































































local new, EditAgent = cluster.genus(Agent)

cluster.extendbuilder(new, function(_new, agent)
   -- Too early to use :setCursor(), so we need to make sure the row is "opened".
   -- We can't just borrow the function from _new because it in turn calls
   -- :openRow(), but we don't need all its safeguards anyway.
   agent[1] = Codepoints("")
   agent.cursor = Point(1, 1)
   agent.contents_changed = false
   agent.cursor_changed = false
   return agent
end)














function EditAgent.contentsChanged(agent)
   Agent.contentsChanged(agent)
   agent.contents_changed = true
end










function EditAgent.setLexer(agent, lex_fn)
   if agent.lex ~= lex_fn then
      agent.lex = lex_fn
      agent:bufferCommand("clearCaches")
   end
end














function EditAgent.currentPosition(agent)
   local row, col = agent.cursor:rowcol()
   return agent[row], col, row
end
















local clamp, inbounds = assert(math.clamp), assert(math.inbounds)
function EditAgent.setCursor(agent, rowOrTable, col)
   local row
   if type(rowOrTable) == "table" then
      row, col = rowOrTable.row, rowOrTable.col
   else
      row = rowOrTable
   end
   row = row or agent.cursor.row
   assert(inbounds(row, 1, #agent))
   agent:openRow(row)
   if col then
      assert(inbounds(col, 1, #agent[row] + 1))
      -- Explicit horizontal motion, forget any remembered horizontal position
      agent.desired_col = nil
   else
      -- Remember where we were horizontally before clamping
      agent.desired_col = agent.desired_col or agent.cursor.col
      col = clamp(agent.desired_col, nil, #agent[row] + 1)
   end
   agent.cursor = Point(row, col)
   agent.cursor_changed = true
end









function EditAgent.cursorIndex(agent)
   local index = agent.cursor.col
   for row = agent.cursor.row - 1, 1, -1 do
      index = index + #agent[row] + 1
   end
   return index
end










local clone = assert(table.clone)
function EditAgent.beginSelection(agent)
   agent.mark = clone(agent.cursor)
end








function EditAgent.clearSelection(agent)
   if agent:hasSelection() then
      agent.cursor_changed = true
   end
   agent.mark = nil
end












function EditAgent.hasSelection(agent)
   if not agent.mark then return false end
   if agent.mark.row == agent.cursor.row
      and agent.mark.col == agent.cursor.col then
      agent.mark = nil
      return false
   else
      return true
   end
end












function EditAgent.selectionStart(agent)
   if not agent:hasSelection() then return nil end
   local c, m = agent.cursor, agent.mark
   if m.row < c.row or
      (m.row == c.row and m.col < c.col) then
      return m.col, m.row
   else
      return c.col, c.row
   end
end

function EditAgent.selectionEnd(agent)
   if not agent:hasSelection() then return nil end
   local c, m = agent.cursor, agent.mark
   if m.row > c.row or
      (m.row == c.row and m.col > c.col) then
      return m.col, m.row
   else
      return c.col, c.row
   end
end













function EditAgent.openRow(agent, row_num)
   if row_num < 1 or row_num > #agent then
      return nil
   end
   if type(agent[row_num]) == "string" then
      agent[row_num] = Codepoints(agent[row_num])
   end
   return agent[row_num], row_num
end










local slice = assert(table.slice)
function EditAgent.nl(agent)
   line, cur_col, cur_row = agent:currentPosition()
   -- split the line
   local first = slice(line, 1, cur_col - 1)
   local second = slice(line, cur_col)
   agent[cur_row] = first
   insert(agent, cur_row + 1, second)
   agent:contentsChanged()
   agent:setCursor(cur_row + 1, 1)
end









function EditAgent.tab(agent)
   agent:paste("   ")
end









local inverse = assert(table.inverse)
local _openers = { ["("] = ")",
                   ['"'] = '"',
                   ["'"] = "'",
                   ["{"] = "}",
                   ["["] = "]"}
local _closers = inverse(_openers)

local function _should_insert(line, cursor, frag)
   return not (frag == line[cursor] and _closers[frag])
end

local function _should_pair(line, cursor, frag)
   -- Only consider inserting a pairing character if this is an "opener"
   if not _openers[frag] then return false end
   -- Translate end-of-line to the implied newline
   local next_char = line[cursor] or "\n"
   -- Insert a pair if we are before whitespace, or the next char is a
   -- closing brace--that is, a closing character that is different
   -- from its corresponding open character, i.e. not a quote
   return next_char:match("%s") or
      _closers[next_char] and _closers[next_char] ~= next_char
end

function EditAgent.insert(agent, frag)
   local line, cur_col = agent:currentPosition()
   if _should_insert(line, cur_col, frag) then
      if _should_pair(line, cur_col, frag) then
         insert(line, cur_col, _openers[frag])
      end
      insert(line, cur_col, frag)
      agent:contentsChanged()
   end
   agent:setCursor(nil, cur_col + 1)
   return true
end










local collect, splice = assert(table.collect), assert(table.splice)
function EditAgent.paste(agent, frag)
   frag = frag:gsub("\t", "   ")
   local frag_lines = collect(lines, frag)
   for i, frag_line in ipairs(frag_lines) do
      if i > 1 then agent:nl() end
      local codes = Codepoints(frag_line)
      local line, cur_col, cur_row = agent:currentPosition()
      splice(line, cur_col, codes)
      agent:setCursor(nil, cur_col + #codes)
   end
   agent:contentsChanged()
end
















local deleterange = assert(table.deleterange)
function EditAgent.killSelection(agent)
   if not agent:hasSelection() then
      -- #todo communicate that there was nothing to do somehow,
      -- without falling through to the next command in the keymap
      return
   end
   agent:contentsChanged()
   local start_col, start_row = agent:selectionStart()
   local end_col, end_row = agent:selectionEnd()
   if start_row == end_row then
      -- Deletion within a line, just remove some chars
      deleterange(agent[start_row], start_col, end_col - 1)
   else
      -- Grab both lines--we're about to remove the end line
      local start_line, end_line = agent[start_row], agent[end_row]
      deleterange(agent, start_row + 1, end_row)
      -- Splice lines together
      for i = start_col, #start_line do
         start_line[i] = nil
      end
      for i = end_col, #end_line do
         insert(start_line, end_line[i])
      end
   end
   -- Cursor always ends up at the start of the formerly-selected area
   agent:setCursor(start_row, start_col)
   -- No selection any more
   agent:clearSelection()
end








local function _delete_for_motion(motionName)
   return function(agent, ...)
      agent:beginSelection()
      agent[motionName](agent, ...)
      return agent:killSelection()
   end
end

for delete_name, motion_name in pairs({
   killForward = "right",
   killToEndOfLine = "endOfLine",
   killToBeginningOfLine = "startOfLine",
   killToEndOfWord = "rightWordAlpha",
   killToBeginningOfWord = "leftWordAlpha"
}) do
   EditAgent[delete_name] = _delete_for_motion(motion_name)
end











local function _is_paired(a, b)
   -- a or b might be out-of-bounds, and if a is not a brace and b is nil,
   -- we would incorrectly answer true, so check that both a and b are present
   return a and b and _openers[a] == b
end

function EditAgent.killBackward(agent, disp)
   disp = disp or 1
   local line, cur_col, cur_row = agent:currentPosition()
   -- Only need to check the character immediately to the left of the cursor
   -- since if we encounter paired braces later, we will delete the
   -- closing brace first anyway
   if _is_paired(line[cur_col - 1], line[cur_col]) then
      agent:right()
      disp = disp + 1
   end
   agent:beginSelection()
   agent:left(disp)
   agent:killSelection()
end













function EditAgent.left(agent, disp)
   disp = disp or 1
   local line, new_col, new_row = agent:currentPosition()
   new_col = new_col - disp
   while new_col < 1 do
      line, new_row = agent:openRow(new_row - 1)
      if not new_row then
         agent:setCursor(nil, 1)
         return false
      end
      new_col = #line + 1 + new_col
   end
   agent:setCursor(new_row, new_col)
   return true
end

function EditAgent.right(agent, disp)
   disp = disp or 1
   local line, new_col, new_row = agent:currentPosition()
   new_col = new_col + disp
   while new_col > #line + 1 do
      _, new_row = agent:openRow(new_row + 1)
      if not new_row then
         agent:setCursor(nil, #line + 1)
         return false
      end
      new_col = new_col - #line - 1
      line = agent[new_row]
   end
   agent:setCursor(new_row, new_col)
   return true
end












function EditAgent.up(agent)
   if agent:openRow(agent.cursor.row - 1) then
      agent:setCursor(agent.cursor.row - 1, nil)
      return true
   -- Move to beginning
   elseif agent.cursor.col > 1 then
      agent:setCursor(nil, 1)
      return true
   end
   -- Can't move at all
   return false
end

function EditAgent.down(agent)
   if agent:openRow(agent.cursor.row + 1) then
      agent:setCursor(agent.cursor.row + 1, nil)
      return true
   else
      local row_len = #agent[agent.cursor.row]
      -- Move to end
      if agent.cursor.col <= row_len then
         agent:setCursor(nil, row_len + 1)
         return true
      end
   end
   -- Can't move at all
   return false
end






function EditAgent.startOfLine(agent)
   agent:setCursor(nil, 1)
end

function EditAgent.endOfLine(agent)
   agent:setCursor(nil, #agent[agent.cursor.row] + 1)
end








function EditAgent.startOfText(agent)
   agent:setCursor(1, 1)
end

function EditAgent.endOfText(agent)
   agent:openRow(#agent)
   agent:setCursor(#agent, #agent[#agent] + 1)
end























local match = assert(string.match)

function EditAgent.scanFor(agent, pattern, reps, forward)
   local change = forward and 1 or -1
   reps = reps or 1
   local found_other_char, moved = false, false
   local line, cur_col, cur_row = agent:currentPosition()
   local search_pos, search_row = cur_col, cur_row
   local search_char
   local epsilon = forward and 0 or -1
   while true do
      local at_boundary = (forward and search_pos > #line)
                       or (not forward and search_pos == 1)
      search_char = at_boundary and "\n" or line[search_pos + epsilon]
      if not match(search_char, pattern) then
         found_other_char = true
      elseif found_other_char then
         reps = reps - 1
         if reps == 0 then break end
         found_other_char = false
      end
      if at_boundary then
         -- break out on agent boundaries
         if search_row == (forward and #agent or 1) then break end
         line, search_row = agent:openRow(search_row + change)
         search_pos = forward and 1 or #line + 1
      else
         search_pos = search_pos + change
      end
      moved = true
   end

   return moved, search_pos - cur_col, search_row - cur_row
end








function EditAgent.leftToBoundary(agent, pattern, reps)
   local line, cur_col, cur_row = agent:currentPosition()
   local moved, colΔ, rowΔ = agent:scanFor(pattern, reps, false)
   if moved then
      agent:setCursor(cur_row + rowΔ, cur_col + colΔ)
      return true
   else
      return false
   end
end

function EditAgent.rightToBoundary(agent, pattern, reps)
   local line, cur_col, cur_row = agent:currentPosition()
   local moved, colΔ, rowΔ = agent:scanFor(pattern, reps, true)
   if moved then
      agent:setCursor(cur_row + rowΔ, cur_col + colΔ)
      return true
   else
      return false
   end
end










function EditAgent.firstNonWhitespace(agent)
   local line = agent[agent.cursor.row]
   local new_col = 1
   while new_col <= #line do
      if match(line[new_col], '%S') then
         agent:setCursor(nil, new_col)
         return true
      end
      new_col = new_col + 1
   end
   return false
end






function EditAgent.leftWordAlpha(agent, reps)
   return agent:leftToBoundary('%W', reps)
end

function EditAgent.rightWordAlpha(agent, reps)
   return agent:rightToBoundary('%W', reps)
end

function EditAgent.leftWordWhitespace(agent, reps)
   return agent:leftToBoundary('%s', reps)
end

function EditAgent.rightWordWhitespace(agent, reps)
   return agent:rightToBoundary('%s', reps)
end




















function EditAgent.replaceToken(agent, frag)
   local cursor_token
   for _, token in ipairs(agent:tokens(agent.cursor.row)) do
      if token.cursor_offset then
         cursor_token = token
         break
      end
   end
   agent:right(cursor_token.total_disp - cursor_token.cursor_offset)
   agent:killBackward(cursor_token.total_disp)
   agent:paste(frag)
end











function EditAgent.transposeLetter(agent)
   local line, cur_col, cur_row = agent:currentPosition()
   if cur_col == 1 then return false end
   if cur_col == 2 and #line == 1 then return false end
   local left, right = cur_col - 1, cur_col
   if cur_col == #line + 1 then
      left, right = left - 1, right - 1
   end
   local stash = line[right]
   line[right] = line[left]
   line[left] = stash
   agent:setCursor(nil, right + 1)
   agent:contentsChanged()
   return true
end









function EditAgent.shouldEvaluate(agent)
   -- Most agents are one line, so we always evaluate from
   -- a one-liner, regardless of cursor location.
   local linum = #agent
   if linum == 1 then
      return true
   end
   local _, cur_col, cur_row = agent:currentPosition()
   -- Evaluate if we are at the end of the first or last line (the default
   -- positions after scrolling up or down in the history)
   if (cur_row == 1 or cur_row == linum) and cur_col > #agent[cur_row] then
      return true
   end
end












function EditAgent.update(agent, str)
   str = str or ""
   local i = 1
   for line in lines(str) do
      agent[i] = line
      i = i + 1
   end
   for j = i, #agent do
      agent[j] = nil
   end
   agent:contentsChanged()
   agent:endOfText()
   return agent
end











function EditAgent.clear(agent)
   agent:update("")
   agent :send { to = "agents.results", method = "clear" }
   agent :send { to = "hist", method = "toEnd" }
end








local function cat(l)
   if l == nil then
      return ""
   elseif type(l) == "string" then
      return l
   elseif type(l) == "table" then
      return concat(l)
   else
      error("called private fn cat with type" .. type(l))
   end
end

function EditAgent.contents(agent)
   local closed_lines = {}
   for k, v in ipairs(agent) do
      closed_lines[k] = cat(v)
   end
   return concat(closed_lines, "\n")
end









function EditAgent.isEmpty(agent)
   return #agent == 1 and #agent[1] == 0
end












function EditAgent.continuationLines(agent)
   return #agent - 1
end









function EditAgent.tokens(agent, row)
   if row then
      local cursor_col = agent.cursor.row == row
         and agent.cursor.col or 0
      return agent.lex(cat(agent[row]), cursor_col)
   else
      return agent.lex(agent:contents(), agent:cursorIndex())
   end
end








function EditAgent.bufferValue(agent)
   local answer = {}
   for i, line in ipairs(agent) do
      answer[i] = cat(line)
   end
   return answer
end









function EditAgent.windowConfiguration(agent)
   return agent.mergeWindowConfig(Agent.windowConfiguration(), {
      field = { cursor = true },
      closure = { cursorIndex = true,
                  tokens = true }
   })
end












function EditAgent.selfInsert(agent, evt)
   return agent:insert(evt.key)
end








function EditAgent.evtPaste(agent, evt)
   agent:paste(evt.text)
end




return new


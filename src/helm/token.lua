





































local byte, codepoints, find, format = assert(string.byte),
                                       assert(string.codepoints),
                                       assert(string.find),
                                       assert(string.format)
local concat, insert, remove = assert(table.concat),
                               assert(table.insert),
                               assert(table.remove)







local Token = meta {}
local new











function Token.toString(token, c)
   local output = {}
   for i, frag in ipairs(token) do
      if token.escapes[frag] then
         frag = c.stresc .. frag .. token.color
      elseif token.err and token.err[i] then
         frag = c.alert .. frag .. token.color
      end
      output[i] = frag
   end
   return token.color(concat(output))
end










function Token.split(token, max_disp)
   local disp_so_far = 0
   local split_index
   for i, disp in ipairs(token.disps) do
      if disp_so_far + disp > max_disp then
         split_index = i - 1
         break
      end
      disp_so_far = disp_so_far + disp
   end
   local first, rest = new(nil, token.color, token.event), new(nil, token.color, token.event)
   first.escapes = token.escapes
   rest.escapes = token.escapes
   for i = 1, #token do
      local target = i <= split_index and first or rest
      target:insert(token[i], token.disps[i], token.err and token.err[i])
   end
   return first, rest
end












function Token.insert(token, pos, frag, disp, err)
   if type(pos) ~= "number" then
      err = disp
      disp = frag
      frag = pos
      pos = #token + 1
   end
   -- Assume one cell if disp is not specified.
   -- Cannot use #frag because of Unicode--might be two bytes but one cell.
   disp = disp or 1
   insert(token, pos, frag)
   insert(token.disps, pos, disp)
   token.total_disp = token.total_disp + disp
   -- Create the error array if needed, and/or shift it if it exists (even if
   -- this fragment is not in error) to keep indices aligned
   if token.err or err then
      token.err = token.err or {}
      insert(token.err, pos, err)
   end
end










function Token.remove(token, pos)
   local removed = remove(token, pos)
   local rem_disp = remove(token.disps, pos)
   token.total_disp = token.total_disp - rem_disp
   local err = token.err and remove(token.err, pos)
   return removed, rem_disp, err
end




















local escapes_map = {
   ['"'] = '\\"',
   ["'"] = "\\'",
   ["\a"] = "\\a",
   ["\b"] = "\\b",
   ["\f"] = "\\f",
   ["\n"] = "\\n",
   ["\r"] = "\\r",
   ["\t"] = "\\t",
   ["\v"] = "\\v"
}

new = function(str, color, event, is_string)
   local token = str and codepoints(str) or {}
   setmetatable(token, Token)
   token.color = color
   token.event = event
   token.is_string = is_string
   token.disps = {}
   token.escapes = {}
   token.total_disp = 0
   if not str then
      return token
   end
   for i, frag in ipairs(token) do
      local disp
      if is_string and (escapes_map[frag] or find(frag, "%c")) then
         frag = escapes_map[frag] or format("\\x%x", byte(frag))
         token[i] = frag
         -- In the case of an escape, we know all of the characters involved
         -- are one-byte, and each occupy one cell
         disp = #frag
         token.escapes[frag] = true
      else
         -- For now, assume that all codepoints occupy one cell.
         -- This is wrong, but *usually* does the right thing, and
         -- handling Unicode properly is hard.
         disp = 1
      end
      token.disps[i] = disp
      token.total_disp = token.total_disp + disp
   end
   if is_string and find(str, '^ *$') then
      token:insert(1, '"')
      token:insert('"')
   end
   return token
end

Token.idEst = new

return new



























































local codepoints = assert(core.codepoints)
local utf8_len, utf8_sub = assert(utf8.len), assert(utf8.sub)
local concat, insert, remove = assert(table.concat),
                               assert(table.insert),
                               assert(table.remove)







local Token = meta {}
local new











function Token.toString(token, c)
   if not token.wrappable then
      return token.color(utf8_sub(token.str, token.start))
   end
   local output = {}
   for i = token.start, #token.codepoints do
      local frag = token.codepoints[i]
      if token.escapes[frag] then
         frag = c.stresc .. frag .. token.color
      elseif token.err and token.err[i] then
         frag = c.alert .. frag .. token.color
      end
      output[i] = frag
   end
   -- Need to pass the length explicitly as we've left a bunch of nils
   -- at the beginning, breaking #output
   return token.color(concat(output, "", token.start, #token.codepoints))
end












function Token.split(token, max_disp)
   local first
   local cfg = { event = token.event, wrappable = token.wrappable }
   if token.wrappable then
      cfg.escapes = token.escapes
      first = new(nil, token.color, cfg)
      for i = token.start, #token.codepoints do
         if first.total_disp + token.disps[i] > max_disp then
            token.start = i
            token.total_disp = token.total_disp - first.total_disp
            break
         end
         first:insert(token.codepoints[i], token.disps[i], token.err and token.err[i])
      end
   else
      first = new(utf8_sub(token.str, token.start, token.start + max_disp), token.color, cfg)
      token.start = token.start + max_disp + 1
      token.total_disp = token.total_disp - max_disp
   end
   return first
end














function Token.insert(token, pos, frag, disp, err)
   assert(token.start == 1, "Cannot insert into a token with a start offset")
   if type(pos) ~= "number" then
      err = disp
      disp = frag
      frag = pos
      -- If we have a codepoints array, our total_disp might exceed its length
      -- because of escapes. If not, total_disp is assumed equal to the
      -- number of codepoints in the string
      pos = (token.codepoints and #token.codepoints or token.total_disp) + 1
   end
   -- Assume one cell if disp is not specified.
   -- Cannot use #frag because of Unicode--might be two bytes but one cell.
   disp = disp or 1
   if token.wrappable then
      insert(token.codepoints, pos, frag)
      insert(token.disps, pos, disp)
      -- Create the error array if needed, and/or shift it if it exists (even
      -- if this fragment is not in error) to keep indices aligned
      if token.err or err then
         token.err = token.err or {}
         insert(token.err, pos, err)
      end
   else
      token.str = utf8_sub(token.str, 1, pos - 1) .. frag .. utf8_sub(token.str, pos)
   end
   token.total_disp = token.total_disp + disp
end












function Token.remove(token, pos)
   assert(token.start == 1, "Cannot remove from a token with a start offset")
   local removed, rem_disp, err
   if token.wrappable then
      removed = remove(token.codepoints, pos)
      rem_disp = remove(token.disps, pos)
      err = token.err and remove(token.err, pos)
   else
      pos = pos or token.total_disp
      removed = utf8_sub(token.str, pos, pos)
      rem_disp = 1
      token.str = utf8_sub(token.str, 1, pos - 1) .. utf8_sub(token.str, pos + 1)
   end
   token.total_disp = token.total_disp - rem_disp
   return removed, rem_disp, err
end














local string_sub = assert(string.sub)

function Token.removeTrailingSpaces(token)
   assert(not token.wrappable, "removeTrailingSpaces not implemented \
      for wrappable tokens")
   assert(token.start == 1, "removeTrailingSpaces not implemented \
      for tokens with a start offset")
   -- Note that we can ignore Unicode here, as we only care about spaces
   local last_non_space = -1
   while string_sub(token.str, last_non_space, last_non_space) == " " do
      last_non_space = last_non_space - 1
   end
   token.str = string_sub(token.str, 1, last_non_space)
   token.total_disp = token.total_disp + last_non_space + 1
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

local byte, find, format = assert(string.byte),
                           assert(string.find),
                           assert(string.format)

new = function(str, color, cfg)
   local token = meta(Token)
   token.str = str
   token.start = 1
   token.color = color
   cfg = cfg or {}
   for k, v in pairs(cfg) do
      token[k] = v
   end
   if not token.wrappable then
      token.total_disp = token.total_disp or utf8_len(str)
      return token
   end
   -- Everything from here on applies only to wrappable tokens,
   -- in practice this means only string literals
   token.codepoints = codepoints(str or "")
   token.err = token.codepoints.err
   token.disps = {}
   token.escapes = {}
   token.total_disp = 0
   if not str then
      return token
   end
   for i, frag in ipairs(token.codepoints) do
      -- For now, start by assuming that all codepoints occupy one cell.
      -- This is wrong, but *usually* does the right thing, and
      -- handling Unicode properly is hard.
      local disp = 1
      if escapes_map[frag] or find(frag, "%c") then
         frag = escapes_map[frag] or format("\\x%x", byte(frag))
         token.codepoints[i] = frag
         -- In the case of an escape, we know all of the characters involved
         -- are one-byte, and each occupy one cell
         disp = #frag
         token.escapes[frag] = true
      end
      token.disps[i] = disp
      token.total_disp = token.total_disp + disp
   end
   if find(str, '^ *$') then
      token:insert(1, '"')
      token:insert('"')
   end
   return token
end

Token.idEst = new

return new

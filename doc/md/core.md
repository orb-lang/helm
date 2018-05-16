# Core


All ``core`` modules are supposed to end up in one consistent namespace.

```lua
local escape_lua_pattern
do
  local matches =
  {
    ["^"] = "%^";
    ["$"] = "%$";
    ["("] = "%(";
    [")"] = "%)";
    ["%"] = "%%";
    ["."] = "%.";
    ["["] = "%[";
    ["]"] = "%]";
    ["*"] = "%*";
    ["+"] = "%+";
    ["-"] = "%-";
    ["?"] = "%?";
    ["\0"] = "%z";
  }

local spatToLit = function(s)
    return (s:gsub(".", matches))
  end
end

local function cleave(str, pat)
   local at = string.find(str, pat)
   return string.sub(str, 1, at - 1), string.sub(str, at + 1)
end

return { spatToLit = spatToLit,
         cleave = cleave}
```

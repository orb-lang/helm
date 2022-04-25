# Keymap parts/sub\-keymaps

Common groups of bindings we can reuse with different targets in different places\.

```lua
local parts = {}
```


## Scrolling

```lua
parts.cursor_scrolling = {
   SCROLL_UP   = { method = "evtScrollUp",   n = 1 },
   SCROLL_DOWN = { method = "evtScrollDown", n = 1 },
   UP          = "scrollUp",
   ["S-UP"]    = "scrollUp",
   DOWN        = "scrollDown",
   ["S-DOWN"]  = "scrollDown",
   PAGE_UP     = "pageUp",
   PAGE_DOWN   = "pageDown",
   HOME        = "scrollToTop",
   END         = "scrollToBottom"
}
```


## Basic editing commands \(nerf\-style, similar to emacs/readline\)

The basic editing commands that are applicable no matter what we're editing\.

\#todo
in vril\. Keeping them in one chunk for now\.

```lua
-- Motions
parts.basic_editing = {
   -- Cursor-key motions
   UP              = "up",
   DOWN            = "down",
   LEFT            = "left",
   RIGHT           = "right",
   HOME            = "startOfLine",
   END             = "endOfLine",
   -- Nerf-specific cursor motions
   ["M-LEFT"]      = "leftWordAlpha",
   ["M-b"]         = "leftWordAlpha",
   ["M-RIGHT"]     = "rightWordAlpha",
   ["M-w"]         = "rightWordAlpha",
   ["C-a"]         = "startOfLine",
   ["C-e"]         = "endOfLine",
   -- Insertion--probably shared with vril-insert but not vril-normal
   ["[CHARACTER]"] = { method = "selfInsert", n = 1 },
   TAB             = "tab",
   RETURN          = "nl",
   PASTE           = { method = "evtPaste", n = 1 },
   BACKSPACE       = "killBackward",
   DELETE          = "killForward",
   -- Nerf-specific kills
   ["M-BACKSPACE"] = "killToBeginningOfWord",
   ["M-DELETE"]    = "killToEndOfWord",
   ["M-d"]         = "killToEndOfWord",
   ["C-k"]         = "killToEndOfLine",
   ["C-u"]         = "killToBeginningOfLine",
   -- Misc editing commands
   ["C-t"]         = "transposeLetter",
}
```


## List selection


- [ ]  \#Todo

  - [ ]  Add NAV\.SHIFT\_ALT\_\(UP|DOWN\), to move a page at a time\.
      Hook them to PgUp and PgDown while we're at it\.

  - [ ]  Add NAV\.HOME and NAV\.END to snap to the
      top and bottom\.

```lua
parts.list_selection = {
   TAB = "selectNextWrap",
   DOWN = "selectNextWrap",
   ["S-DOWN"] = "selectNextWrap",
   ["S-TAB"] = "selectPreviousWrap",
   UP = "selectPreviousWrap",
   ["S-UP"] = "selectPreviousWrap"
}
```


## Global commands

Just quit, for now, but I imagine we'll have at least a couple more\.

```lua
parts.global_commands = {
   ["C-q"] = { to = "modeS", method = "quit" }
}
```


## Mass targeting

Function to quickly assign the same target \(by setting Message\.to\) to
all bindings in a proto\-keymap\.

\#todo
smarter agents, ???

```lua
local clone = assert(core.table.clone)

function parts.set_targets(target, bindings)
   bindings = clone(bindings)
   for key, action in pairs(bindings) do
      -- #todo duplicating code in Keymap constructor, should ultimately be
      -- constructing Messages here but need to think about mutability.
      if type(action) == "string" then
         action = { method = action, n = 0 }
      else
         action = clone(action)
         action.n = action.n or #action
      end
      action.to = action.to or target
      bindings[key] = action
   end
   return bindings
end
```

```lua
return parts
```
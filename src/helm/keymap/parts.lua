




local parts = {}






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














parts.list_selection = {
   TAB = "selectNextWrap",
   DOWN = "selectNextWrap",
   ["S-DOWN"] = "selectNextWrap",
   ["S-TAB"] = "selectPreviousWrap",
   UP = "selectPreviousWrap",
   ["S-UP"] = "selectPreviousWrap"
}








parts.global_commands = {
   ["C-q"] = { to = "modeS", method = "quit" }
}












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



return parts


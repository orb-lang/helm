# Render flow and change detection

A Zone ultimately needs to re\-render if:


1. The POT that is ultimately being rendered has changed
   1. It has been swapped out entirely
      - New list of suggestions
      - Cursor to a new history entry
      - New results after evaluation
      - Rainbuf isn't built from a Window and has been explicitly told "here have
          new contents" \(or is this \(2\)?\)
   2. Or it has been mutated/its value has changed
      - Change in selection for suggestions or search results
      - Typing a character, the string in the command zone changes
      - Changing the status of a session premise

2. Something about the Rainbuf has changed\.
   - Scrolling \(\.offset has changed\)
   - Which premise is selected might be stored here as well, though perhaps
       that's questionable?
   - See \(1a\), Rainbuf has new non\-dynamic content
   - See \(3\), if the Rainbuf is informed of height changes as well as width
   - Anything else?

3. Something about the Zone has changed\.
   - Show/hide
   - Border show/hide \(not currently handled and rarely comes up\)
   - Bounds change\. Maybe this is \(2\), handled by the Rainbuf? We already
       inform it of width changes, and really it should handle scrolling more
       completely in which case it would need to know height as well\.
   - Switch to displaying a different Rainbuf/from a different Window

\(1a\) and \(1b\) should both be handled by the Agent and/or its Window, such that
they're transparent to the Rainbuf, but the distinction is worth making because
it means being careful about handing out mutable references/calling methods on
things like SelectionList\.

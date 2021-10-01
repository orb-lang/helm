## Re: keymaps

Some way of having multiple actions bound to a keypress? Examples \(all from Nerf\):

-  The mouse wheel and Shift\+up/down both scroll the results area, **except** that if there are available completions, Shift\+up/down instead switches to Complete\.

-  Up and down arrows, which try moving the cursor and if it's already at the top/bottom scroll through history\.

-  Certain ASCII characters \(? and /\), which enter search and help respectively iff they're the first character entered, otherwise fall back to normal self\-insert behavior\.
Would be nice to be able to express this by binding a sequence of commands, each of which decides whether execution continues\. So for the results scrolling, bind everything to \`scrollResults\{Up|Down\}\`, then prepend an additional binding for the arrow keys, something like \`tryEnterCompletion\`\. There's an analogy here to JavaScript events with stopPropagation\(\), though the order is explicit rather than derived from DOM nesting\.

Seems like many commands will be implemented directly by an Agent, so keymaps need some way to cause the command to be sent directly **to** an Agent\. Some combination of:

-  The keymap itself has a "receiver" or "target" or whatever and commands found in that keymap go to that target rather than starting at top level\. I know you've talked about needing to be able to load keymaps from user config, but the keymap could easily enough be identified **by** its target, like there'd be a keymap named "<global>" or something for stuff not attached to an agent, and then "edit" and "results" and so on\. User extensions could\.\.\.well, could **be** an agent for one thing, in which case the name is obvious, or if not, would just need to make up a name\.

-  The command is a Message and can `sendto = "agents.edit"`, or it'd be nice if it could be just `sendto = "edit"`\.

We do need to deal with the fact that most Agent methods expect specific, meaningful arguments rather than \(maestro, event\), so we need a mechanism to transform the event and extract those arguments\. We'll need something even more complete anyway for `vril`, to deal with accumulating commands like `d3w`, so probably that will take care of this\. Needs design though\.


## Re: inter\-agent messaging

Right now there are a number of places where changes in one Agent ultimately cause the re\-rendering of multiple buffers, and possibly other reactions by other Agents besides:

-  When the command zone/EditAgent changes, the prompt may need more or less continuation lines, though most of the time this doesn't change\. It's cheap to re\-render though\. Currently this is "pulled" by a holdover of the \.touched/checkTouched mechanism\.

-  Also when EditAgent changes, we may need to update suggestions or search results\. \(This may result in a modeshift if we accept a completion or back out of Complete mode\.\) This is currently handled by the onTxtbufChanged/onCursorChanged mechanism\.

-  In Review mode, a change in premise selection needs to update the EditAgent with the new premise title\. This is ad\-hoc handled by the raga, which prevents SessionAgent from totally taking over this functionality\.

-  **Rendering** of the command zone depends on history\-search results or suggestions \(though not both at the same time\), so the zone needs a re\-render if they have changed\-\-and while the usual reason for this is, itself, a contents change in the command zone such that it will be re\-rendered anyway, moving the cursor can also do it, so we do need a mechanism to feed things back\. Right now this is handled directly in Txtbuf, again using a holdover of the \.touched/checkTouched mechanism\. It's pretty awkward to move that responsibility **entirely** to EditAgent, but\.\.\.maybe we should? One thought\-\-this might be a case where message replies would be appropriate, that when EditAgent \(somehow, see below\) informs SuggestAgent or SearchAgent that it has changed, they can write back and be like "hey you'll need a re\-render"\.

There's an important question of where responsibility and control lies, here\. It could certainly be that the EditAgent explicitly sends a message to SuggestAgent and/or SearchAgent when its contents change\. Personally though I think it shouldn't know this\-\-and I think there's a functional reason for it not to in that user extensions might also want to watch this event\. So this is where I keep coming from re: "broadcast" events \(we may have slightly different ideas of what exactly that means\)\-\-some way for the EditAgent to say "I am able to inform people when I change", and others to say "yes please I would like that", and EditAgent to not have to specifically know **who** it's informing\.

If we replace contents\_changed/<Raga>\.onTxtbufChanged etc, we should probably still retain batching/deferral of content\-change events, since more complex editing commands might fire off a bunch of them at once in a naive implementation \(and I say naive, but that's probably also the most **elegant** implementation in a lot of cases\)\.


## Re: agent/buf communications

Okay, I am just really not convinced that only talking to the bufs via the queue is a good idea\. When you're interacting with the user, fundamentally you often need to know things about what's on screen, and pretending that's not the case isn't going to work\. Not explaining this well, but, specific example\. `ResultListAgent` can handle the `ensureVisible` after a selection change now, wonderful, that **seems** like a legit significant improvement\. When it comes to `SessionAgent` though, suddenly in order to know what should be visible we need to know how many lines the results take up, and yeah I can implement a `:ensureSelectedVisible()` on Sessionbuf but ugh, it's just **noise**\.

Also like, should the Agents **really** know about scrolling **at all**? It's an elegant way to create an **apparent** separation between Doing Stuff and rendering, but at the same time I worry that it's conflating responsibilities and awareness that should be kept separate\. Part of that is MVP experience speaking, where editing commands would be primarily handled by the model and scrolling by\.\.\.mostly the view but the presenter could involve itself if needed\.
# Femto


I just got orb stood up in the pylon bootloader distribution.


I am excited about this.


## includes

This all goes into global space for now.  Our more sophisticated loader will
handle namespace isolation. Meanwhile we're building a repl, so.

```lua
sql = require "sqlite"

lfs = require "lfs"
ffi = require "ffi"

ffi.reflect = require "reflect"

uv = require "luv"

L = require "lpeg"

a = require "anterm"

c = require "color"

core = require "core"

watch = require "watcher"
```
#### utils

```lua

local usecolors
stdout = ""

if uv.guess_handle(1) == "tty" then
  stdout = uv.new_tty(1, false)
  usecolors = true
else
  stdout = uv.new_pipe(false)
  uv.pipe_open(utils.stdout, 1)
  usecolors = false
end

if not usecolors then
   c.ts = tostring
   -- #todo make this properly black and white ts
end

function print(...)
  local n = select('#', ...)
  local arguments = {...}
  for i = 1, n do
    arguments[i] = tostring(arguments[i])
  end
  uv.write(stdout, table.concat(arguments, "\t") .. "\n")
end

function write(str)
   uv.write(stdout, str)
end


--  *** tty setup

if uv.guess_handle(0) ~= "tty" or
   uv.guess_handle(1) ~= "tty" then
  -- Entry point for other consumers!
  error "stdio must be a tty"
end

local stdin = uv.new_tty(0, true)


--  *** utilities

local function gatherResults(success, ...)
  local n = select('#', ...)
  return success, { n = n, ... }
end

local function printResults(results)
  for i = 1, results.n do
    results[i] = c.ts(results[i])
  end
  print(table.concat(results, '\t'))
end

local buffer = ''

local function evaluateLine(line)
   if string.byte(line) == 17 then -- ^Q
      uv.stop()
      return 0
   end
   local chunk  = buffer .. line
   local f, err = loadstring('return ' .. chunk, 'REPL') -- first we prefix return

   if not f then
      f, err = loadstring(chunk, 'REPL') -- try again without return
   end

   if f then
      buffer = ''
      local success, results = gatherResults(xpcall(f, debug.traceback))

      if success then
      -- successful call
         if results.n > 0 then
            printResults(results)
         end
      else
      -- error
         print(results[1])
      end
   else
      if err:match "'<eof>'$" then
         -- Lua expects some more input; stow it away for next time
         buffer = chunk .. '\n'
         return '...'
      else
         print(err)
         buffer = ''
      end
   end

   return '👉  '
end

local function displayPrompt(prompt)
  uv.write(stdout, prompt)
end

-- Deprecated, but useful if I want, y'know, a REPL
local function onread(err, line)
  if err then error(err) end
  if line then
    local prompt = evaluateLine(line)
    displayPrompt(prompt)
  else
    uv.close(stdin)
  end
end
```
## Reader

The reader takes a stream of data from ``stdin``, asynchronously, and
processes it into tokens, which stream to the recognizer.


#### keybuf

 Currently the keybuf is a simple array that holds bytes until we have
enough for the lexer.


It is cleared and reused, to avoid a glut of allocations and allow the tracer
to follow it.


Soon I'll move the remaining local state into an instance table, to make
``femto`` re-entrant.

```lua
local keybuf = {}
local sub, byte = string.sub, string.byte
local concat = table.concat

local linebuf = { line = "",
                  ndx  = 0 }

local max_row, mac_col = uv.tty_get_winsize(stdin)

```
### helper functions

Writes will eventually happen in their own library.  Right now we're building
the minimum viable loop.

```lua
-- This will be called parse_digits and be substantially more complex.
--
local function cursor_pos(str)
   local row, col = core.cleave(str, ";")
   return tonumber(row), tonumber(col)
end

-- this is exploratory code
local function colwrite(str, col)
   col = col or 81
   local dash = a.stash()
             .. a.jump(1, col)
             .. a.erase.right()
             .. str
             .. a.pop()

   write(dash)
end

local STAT_ICON = "◉"

local function process_escapes(seq)
   local term = sub(seq, -1)
   local csi  = sub(seq, 2, 2) == "[" and true or false
   local payload
   local ltrim = csi and 3 or 2
   if #seq > ltrim then
      payload = sub(seq, ltrim, -1)
   end
   if term == "R" then
      local row, col = cursor_pos(payload)
      -- send them along
   elseif term == "A" then
      -- up
   elseif term == "B" then
      -- down
   elseif term == "C" then
      -- left
   elseif term == "D" then
      -- right
   else
      return write(seq)
   end
end

local function lexer(seq)
   -- This front matter belongs in the escape handling code.
   if byte(seq) == 27 then
      colwrite(a.magenta(STAT_ICON) .. " : " .. c.ts(seq))
      process_escapes(seq)
      return
   end
   colwrite(a.green(STAT_ICON) .. " : " .. seq)
   write(seq)
end
```
## onkey(err, key)

We buffer escape sequences and codepoints, passing the completed strings
through to the lexer.


I've never seen an xterm parsing state machine diagram.  I intend to correctly
parse the full set of possible utf-8 compatible control sequences and assign
them canonical names as tokens, though of course ``bridge`` will only ship with
actions on a subset of these.


``onkey`` is also where corruption is absorbed. It should be possible to make
``/dev/random`` into stdin without ``onkey`` throwing exceptions or breaking its
contract with the lexer.


The required behavior is to resynchronize any utf-8 bytes that cannot form a
valid codepoint, by dropping the contents of the keybuf when we go out of
range.


An optional behavior would be to drop the ``0`` byte.  While harmless in Lua,
which has 8 bit clean strings and is even smart enough to consider it ``true``,
it can cause disaster in C.  Although **mandated** to be part of the standard,
in practice emitting utf-8 with ``0`` in it is hostile behavior.


As a compromise, we'll have a ``TOK.ZERO`` token.  Responsibility for detecting
and tokenizing ``0`` belongs to the lexer.


### state machine

My intention is to fully diagram the state machine of ``onkey`` as a claim about
its behavior.


``plantuml`` is a lumbering piece of Java, something I want to start up and
use as a server, but that and C will be my first extensions to the knit
module.


In the meantime:


#### xterm: some observations

The definitive reference is [RTFM](http://rtfm.etla.org/xterm/ctlseq.html).


This is lacking some current features, notable 24 bit color. I will cite
any extensions which aren't justified by the reference above.


##### esc: ^[, 033, 27, 0x1b: seq[0]

As a general consideration, printable characters will be referred to by name,
not value. ``a == 0142 == 97 == 0x61`` will be called ``a``.  I will otherwise
prefer the hexadecimal.


Our terminals are quite unable to parse the C1 8 bit control signals, which
belong to the extended character range.


Therefore all escape sequences begin with this byte:

```ggg
xterm = esc      ; to be continued
esc   = 0x1b
```

The "Single character functions" section of vt100 contains behaviors for
control characters.  These are out of scope for our parser.


##### seq[1]

I will use guillemets to mark a set, like so: «abcd».  This is non-standard
but clearer than escaping e.g. ``{}``.


The following second characters are recognized into token classes. A token
name refers to the two-byte sequence concatenating ``0x1b`` and the indicated
value.


- "[" :  Token ``CSI``.  Most common seq[1].
         If encountered, there exists a seq[2].


- «DEHMNOVWXZ]^» :  C1 terminators.  Any seq[1] in this class ends the
                         parse.


                         Each has its own token name.


                         **note: I am going through the spec in order.**


                         **This class may contain invalid members right now**


                         At this point I doubt it having moved these:


- "P" :  Token ``DCS``, Device Control String.


- "_" :  Token ``APC``, Application Program Command.


         These are the tricky ones because they consume all input up to:


- "\" :  Token ``ST``, String Terminator.


         Between ``DCS`` or ``APC`` and the ending ``ST`` is ``Pt``, defined as "a
         text parameter composed of printable characters".


         I choose to interpret that as an optional (may be length 0) string
         of those utf-8 sequences which are not control characters.


         I further define ``ST`` as valid if not proceeded by an ``APC``; the
         standard implies as much.


         In either case, ``ST`` is a terminal parse.


         An important consequence: The length of ``seq`` has no upper bound.


         Any xterm parser which intends to retain escape sequences until
         completed must have a plan for an ``APC`` string of unlimited duration.


         Note that I said _duration_. This is best implemented as a modal
         pass-through.


         Consequentially, I define it as **valid** for ``Pt`` to end without a
         corresponding ``ST``.  Errors which can reach into the gigabytes are a
         dicey proposition.


         The question then arises: what of escape sequences within ``Pt``? It
         says 'printable' and that excludes control sequences with a few
         traditional exceptions; it never includes ``0x1b``.


         I think they have to be dropped from the input stream. Otherwise
         ``ST`` is just ``0x1b``.


         I'm going to define printable control characters as ``0x9``, ``0xa``, and
         ``0xD``.  I consider that to be in accordance with modern practice.


         ``DCS`` requires additional parsing before accepting all non ``ST`` utf-8
         data.  See below.


- " " :  Token ``SP``.  Always followed by a seq[2].


- "#" :  Funky double-line DEC modes.  Followed by a seq[2] which is a subset
         of digits: ``{ 34568 }``.


- "%" :  Character set.  Has seq[2]: "@" | "G", indicating ISO 8859-1 and
         UTF-8, respectively.


The letter "C" is reserved by the standard to refer to specific characters,
at least in the seq[1] position.  My conclusion is that ``0x1b'C'`` is invalid
and should be discarded by the parser.


- «()*+» C :  It is understood that ``C`` refers to a set defined below.


                These designate character sets ``G0,G1,G2,G3``, in order of
                sense, and are modified by ``C`` accordingly:


- C `` «0AB4C5RQKYE6ZH7``» :  A variety of European encodings with several
                              (apparent) pseudonyms.  Alas, Babel.


The following list are terminals at seq[1]:


- "7", "8" :  Save and restore cursore.  Broadly supported.


- «=>Fclmno|}~»:  Relevant, not using. <tk> semantics.


#### DCS

#NYI### CSI : seq[3]

CSI codes are of variable but definite length.  They will terminate or prove
malformed given finite input.


When I figure out the upper bound I will describe it here.


``MAX_SAFE_INTEGER`` is defined as 9007199254740991, which is sixteen characters
wide in decimal.


#### CSI: Ps

The standard defines Ps thus:


> A single (usually optional) numeric parameter,
> composed of one of more digits.


Usually optional! Delightful.


We will use ``Px`` and ``Po`` to denote required and optional digit parameters.


There is also ``Pm``, for multiple ``Po`` of arbitrary length, separated by a ";"
but not terminated thus.  We do not use ``Pn`` because of the potential for
confusion.


We also must have ``Pd`` for some definite subset of digit values.  Each
``Pd`` is bespoke and the standard won't be done until we have parsing classes
for each.


Because the ``P`` class are variable-length encoded, and no upper bound is
given, it is possible to produce a weird machine by feeding an absurd amount
of digits to the parser.


``MAX_SAFE_INTEGER`` is defined as 9007199254740991, which is sixteen characters
wide in decimal. Therefore, any ``Px`` may be up to fifteen digits in width.


Our ``MAX_PX`` is the string "999999999999999".  A conforming implementation
must be able to represent that number as a signed integer.


### interlude

Completing this in a single afternoon would be fatiguing, and preclude other
more immediately useful work.


From this point forward I'm cherry-picking CSI sequences which I actually
need.


#### CSI: glyph prequels

The set «?>!» appear to constitute the sole valid prequels, that is, they
may be seen before any ``Po``.


I believe they are required to be ``seq[2]``.


Other glyphs which may be found after a ``Po`` or such are «@`{|&», none of
which I intend to support at present.


I will also gloss for now all ``[a-zA-Z]`` as both valid and terminal.


````` appears to be uniquely bad, valid as a terminal for ``Pm`` by itself and
otherwise a penultimate.  I'll circle back for it.


``~`` doesn't appear in the spec, which is weird because it's a terminal for
such basic signals as ``PgDn``. We treat it as a terminal; it is.


```lua
local function isnum(char)
   return char >= "0" and char <= "9"
end

local function isalpha(char)
   return (char >= "A" and char <= "z")
      or  (char >= "a" and char <= "z")
end

local _C1terms = {"D","E","H","M","N","O","V","W","X","Z","]","^"}

local C1Termset = {}

for i = 1, #_C1terms do
   C1Termset[ _C1terms[i]] = true
end

_C1terms = nil


local function C1Terminal(char)
   return C1Termset[char]
end

local function CSIPrequel(char)
   if char == "?" or char == ">" or char == "!" then
      return true
   end
end



-- These state flags should be closed over to make
-- onkey re-entrant.

-- This will allow our parser to be re-used by user
-- programs without interfering with the repl.
--

local escaping = false
local csi      = false
local wchar    = false

local function onkey(err, key)
   if err then error(err) end
   -- ^Q to quit
   if key == "\17" then
      femto.cooked()
      uv.stop()
      return 0
   end
   if key == "\27" then
      escaping = true
      keybuf[#keybuf + 1]  = key
      return
   end
   if escaping then
      if csi then
         -- All CSI parsing
         assert(#keybuf >= 2, "keybuf too small for CSI")
         assert(keybuf[1] == "\27", "keybuf[1] ~= ^[")
         assert(keybuf[2] == "[", "keybuf ~= ^[[")
         if CSIPrequel(key) then
            assert(#keybuf == 2, "CSIPrequel must be keybuf[3]")
            keybuf[3] = key
            return
         end

         if isnum(key) or key == ";" then
            keybuf[#keybuf + 1] = key
            return
         end

         if isalpha(key) or key == "~" then
            escaping, csi = false, false
            local esc_val = concat(keybuf) .. key
            for i = 1, #keybuff do keybuf[i] = nil end
            return lexer(esc_val)
         else
            error("possible invalid during csi parsing: " .. key)
            return
         end
      -- detect CSI
      elseif key == "[" then
         csi = true
         assert(keybuf[2] == nil, "[ was not in CSI position")
         keybuf[2] = key
         return
      elseif C1Terminal(key) then
         -- seq[2]
         assert(keybuf[2] == nil, "CSITerminal with non-nil keybuf[2]")
         escaping = false
         keybuf[1] = nil
         return lexer("\27" .. key)
      else
         -- This is not yet correct!
         keybuf[#keybuf + 1] = key
         return
      end
   elseif not wchar then
      -- if not escaping or wchar then check ASCIIness
      if key <= "~" then
         return lexer(key) -- add some kind of mode parameter
      else
         -- backspace, wchars etc
      end
   end
   return lexer(key)
end
```
```lua
-- Get names for as many values as possible
-- into the colorizer
c.allNames()
-- This switches screens and does a wipe,
-- then puts the cursor at 1,1.
write '\27[?47h\27[2J\27[H'
print "an repl, plz reply uwu 👀"
displayPrompt '👉  '
-- Crude hack to choose raw mode at runtime
if arg[1] == "-r" then
   femto.raw()
   uv.read_start(stdin, onkey)
else
   uv.read_start(stdin, onread)
end



-- main loop
local retcode = uv.run('default')
-- Restore
print '\27[?47l'

if retcode ~= 0 then
   error(retcode)
end

print("kthxbye")
return retcode
```

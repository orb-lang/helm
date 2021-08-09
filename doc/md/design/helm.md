
@startuml
class Modeselektor
class Historian
package "zone\.orb" as zone\_orb <<Folder>> \{
   class Zoneherd
   class Zone
\}
class Valiant
class Maestro

class Agent
class Editagent
class Sessionagent
class Suggestagent
class Resultagent

Agent \-\-\* Editagent
Agent \-\-\* Sessionagent
Agent \-\-\* Suggestagent
Agent \-\-\* Resultagent


class Window
class Mailbox

class Rainbuf
class Textbuf
class Resultbuf
class Suggestbuf
class Sessionbuf

Rainbuf \-\-\* Textbuf
Rainbuf \-\-\* Resultbuf
Rainbuf \-\-\* Suggestbuf
Rainbuf \-\-\* Sessionbuf

object hist
object eval

object suggestWindow
object editWindow
object resultWindow
object sessionWindow

rectangle "bufs" as BUF \{
   map suggestBuf \{
      suggestWindow \*\-\-> suggestWindow
   \}

   map textBuf \{
      editWindow \*\-\-> editWindow
   \}

   map resultBuf \{
      resultWindow \*\-\-> resultWindow
   \}

   map sessionBuf \{
      sessionWindow \*\-\-> sessionWindow
   \}
\}

map bufs \{
   suggestBuf \*\-\-> BUF\.suggestBuf
   textBuf \*\-\-> BUF\.textBuf
   resultBuf \*\-\-> BUF\.resultBuf
   sessionBuf \*\-\-> BUF\.sessionBuf
   more => \.\.\.
\}

object zoneBox
object maestroBox

map zoneherd \{
    maestroBox \*\-\-> maestroBox

    bufs \*\-\-> bufs
    prompt   `> Zone> Zone
 
    suggest `   result  `> Zone> Zone
\}
    command `

rectangle "agents" as AG \{
object suggestAgent
object editAgent
object resultAgent
object sessionAgent
\}


map agents \{
   suggestAgent \*\-\-> AG\.suggestAgent
   editAgent \*\-\-> AG\.editAgent
   resultAgent \*\-\-> AG\.resultAgent
   sessionAgent \*\-\-> AG\.sessionAgent
\}

map maestro \{
   agents \*\-\-> agents
   zoneBox \*\-\-> zoneBox
   more => \.\.\.
\}

map modeS \{
   zones \*\-\-> zoneherd
   hist  \*\-\-> hist
   maestro \*\-\-> maestro
   eval    \*\-\-> eval
\}

circle "new" as newSuggestAgent
circle "new" as newEditAgent
circle "new" as newResultAgent
circle "new" as newSessionAgent

circle "new" as newZoneMailbox

Modeselektor \-\-|> modeS : new
Zoneherd \-\-|> zoneherd : new
Zone \-\-|> suggest : new
Zone \-\-|> command : new
Zone \-\-|> result  : new
Historian \-\-|> hist : new
Valiant \-\-|> eval : new
Maestro \-\-|> maestro : new

Suggestagent \-\-|> newSuggestAgent
Editagent \-\-|> newEditAgent
Resultagent \-\-|> newResultAgent
Sessionagent \-\-|> newSessionAgent
Window \-\-|> suggestWindow : new
Window \-\-|> editWindow : new
Window \-\-|> resultWindow : new
Window \-\-|> sessionWindow : new
newSuggestAgent \-\-> suggestAgent
newSuggestAgent \-\-> suggestWindow
newEditAgent \-\-> editAgent
newEditAgent \-\-> editWindow
newResultAgent \-\-> resultAgent
newResultAgent \-\-> resultWindow
newSessionAgent \-\-> sessionAgent
newSessionAgent \-\-> sessionWindow

Suggestbuf \-\-|> suggestBuf
Resultbuf \-\-|> resultBuf
Textbuf \-\-|> textBuf
Sessionbuf \-\-|> sessionBuf

Mailbox \-\-|> newZoneMailbox
newZoneMailbox \-\-> zoneBox
newZoneMailbox \-\-> maestroBox

@enduml

# Migration 7: The Great Normalization\.

We're making a lot of changes here\.

The overarching goal is to have a fully\-normal database\.

We're going to end up with what feels like a lot of tables, because that's the
price of orthogonality, that and a lot of joins to get data out of the
database\.

We'll be happy about this\! I'm sure\.

I'm presuming a full copy of every table in the database, which will be fun,
order wise\.

Meanwhile, let's write that new schema\.


## Migration 7: Schema

This one leaves no table untouched\.


### project

We'll drop the time field, which is never used nor useful, add a project name,
and a `fact` table\.  We'll probably end up using that to store Manifest data,
and foreign keys into e\.g\. modules and orb databases\.

```sql
CREATE TABLE project_copy(
   project_id INTEGER PRIMARY KEY,
   directory TEXT,
   name TEXT,
   fact LUATEXT
);
```


### lines

A unique text table\. Should probably be strict\.

```sql
CREATE TABLE line (
   line_id INTEGER PRIMARY KEY,
   string TEXT UNIQUE NOT NULL,
   hash TEXT,
);

CREATE INDEX line_text_id ON line (string);
CREATE INDEX line_hash_id ON line (hash);
```

Add null line `""` with hash\.


#### lines: what they are, what they aren't

We *could* store all strings in one big table, but we don't\.

Lines are, roughly, anything a user has personally entered into helm\.

This includes premises and input, it doesn't include error strings, or strings
returned by the repl\.

There are some edge cases, like session titles, where I don't see the point in
storing it as a foreign key to the line table\.  We might change our minds
about those, the important part is that a line is not simply lines of code
which have been input into helm\.


#### A Note on the Hash Field

The shape of our data is such that most lines will be short, while some could
be very, very long, simply because we compose no constraints on what a line
can be\.

SQLite can handle this data shape fairly expediently, but we should make a
habit of including the hash, so that we can query with it above some empirical
threshold \(4K?\)\.

But we needn't populate it in most cases, because the hash is a pure function
of a line, and we can treat it as a cache which gives consistent performance
for certain classes of query\.

We'll have `line_id` foreign keys all over the place, and row\_id encoding and
query planning is as good as it gets\.

There's a whole attestation engine coming for signing data, and that will only
ever use hash digests, another good reason to have a slot for a hash\.

Generally, so long as we cache the hash for consistent reasons, we can use it
when interested in the subset of lines which meet those criteria\.


### input

Input is no longer a table, but rather a particular sort of `run_action` which
points at a round\.


### round

A line is now an interned string, which can be retrieved by key or identity,
and sometimes by hash\.

An **instance** of a line is identified by a round\.

This is the pivot table to make all our aggregates agree with one another\.

What should this look like?

```sql
CREATE TABLE round(
   round_id INTEGER PRIMARY KEY,
   line INTEGER NOT NULL,
   response INTEGER NOT NULL,
   FOREIGN KEY (line)
      REFERENCES line (line_id)
   FOREIGN KEY (response)
      REFERENCES response (response_id)
);
```

Note that the round points to the response, not the other way around\. Because
`2 + 3` and `1 + 4` have the same response, we only actually need one copy of
it, and this should be cheap to deduplicate when transacting a round to the
database\.

Instead we insist that the line exist, and the response is created, before we
can commit a round\.


#### rounds: stateless, rather than unique

Lines are kept unique, so that two foreign keys compare as equivalent to the
strings, or their hash\.

A line, coupled to its response, we call a round\.

Rounds are stateless, rather than unique\.  Any two lines with identical
responses *may as well be* the same round, and we take opportunities to
deduplicate stateless entities in the database\.

But because rounds and responses are themselves composed of unique data, we
have no need to enforce the uniqueness of the compounds\.

We might find that it's practical to promote these to unique values, we might
not\.  This is probably a case where the strictness would cause more problems
than it solves\.


### response

Response is a degenerate table, a pure identity\.

```sql
CREATE TABLE response(
   response_id INTEGER PRIMARY KEY
);
```


This gives us referential integrity\.  With the right transactional semantics,
we will always create a round with its line, responses, and whatever points to
it \(canonically input\), and if this changes, we transactionally update the
state\.

This will also allow deduplication of responses, because responses are
stateless, though not unique\.  As we'll see this is not fully automatic but
tractable in many cases\.

Many things can point at a response, things which are logically mutually
exclusive\.  It should be possible to engineer the database to prohibit more
than one of these from existing, so that we don't have a round with both an
error and a result, which is also `'pending'`\.

It's okay to leave things up to transactional and application logic, though\.


### result

  `result` now points to a `response`, and includes an ordinal, which makes it
efficient to retrieve a response which is already defined in terms of the
given results\.

\#Todo
change structure, as it happens\.



```sql
CREATE TABLE IF NOT EXISTS result_copy (
   result_id INTEGER PRIMARY KEY,
   response INTEGER NOT NULL,
   ordinal INTEGER NOT NULL CHECK (order > 0),
   hash TEXT NOT NULL,
   UNIQUE(response, ordinal)
   FOREIGN KEY (response)
      REFERENCES response (response_id)
      ON DELETE CASCADE
   FOREIGN KEY (hash)
      REFERENCES repr (hash)
);
```

Here's how we can deduplicate results:

I will head deep into the SQL mines, and return with a query\.

We take the last ordinal, and retrieve all responses which have the hash\.

In the case of one result, this deduplicates our query, for other cases we
must compare the other ordinals and reject matches\.

That's the long case, we can provide custom queries for, say, up to four
results\.

How many times are there five results? Not often I'm sure\.

We have more response types, but these are less central and work the same way\.


### repr

The reprs need to be re\-hashed, but retain the same structure\.

I think we'll drop blob affinity though, it's not in fact a blob, it's valid
utf8\.

```sql
CREATE TABLE repr_copy (
   hash TEXT PRIMARY KEY ON CONFLICT IGNORE,
   repr BLOB
);
```


### riff

  A `riff` is an ordered series of `rounds`, therefore a pointer, or rather, a
'pointed'\.


```sql
CREATE TABLE riff (
   riff_id INTEGER PRIMARY KEY,
);
```

What points to it is a `riff_round`, which is a round with a specific order in
a particular riff\.


### riff\_round

  This is the 'pure' identity of a round within a riff, which includes its
order within the riff\.


```sql
CREATE TABLE riff_round(
   riff_round_id INTEGER PRIMARY KEY,
   riff INTEGER NOT NULL,
   ordinal INTEGER NOT NULL CHECK (order > 0),
   round INTEGER NOT NULL
   UNIQUE (riff, ordinal)
   FOREIGN KEY (riff)
      REFERENCES riff (riff_id)
   FOREIGN KEY (round)
      REFERENCES round (round_id)
);
```

We use transactions, as you'd imagine, to insure that an input and a riff
point at the same round\.


### run

  A Run is a record of everything which happens in a given run of helm, from
launch to quit\.

The Run itself holds any singular fact about the run, such as launch time and
quit time, serving otherwise as a foreign key for run actions\.

```sql
CREATE TABLE run_copy (
   run_id INTEGER PRIMARY KEY,
   project INTEGER NOT NULL,
   start_time DATETIME DEFAULT (strftime('%Y-%m-%dT%H:%M:%f', 'now')),
   finish_time DATETIME,
   latest_riff INTEGER,
   FOREIGN KEY (project)
      REFERENCES project (project_id)
      ON DELETE CASCADE
   FOREIGN KEY (latest_riff)
      REFERENCES riff (riff_id)
);
```

The `latest_riff` is the last riff which ran during this run, or the current
riff for a session\-in\-progress\.  It may or may not have ended cleanly,
determining this involves checking the last `run_action`\.

Note that Runs produce riffs, but are composed of run actions, as well as the
latest riff\.  We track the latest riff twice, to distinguish crashing or
SIGKILL from clean exits\.


#### run action

Run actions used to use a \(run, ordinal\) pair, but a primary key is more
useful\.

Since the most important run action is input, we have an optional `round`
column to point at rounds in that instance\.

We also move the timestamp to the run actions\.  About that: the kinds of
problems caused by clock skew aren't worth having\.  We still want to know at
what time an action happened, but we *don't* want to use that to reconstruct
a run order\.  An autoincremented primary key is better here\.

Note the `fact` field, which can contain a serpent\-serialized Lua table with
anything we need to know about a run action\.  `LUATEXT` gives text 'affinity',
while showing the intention\.

It will be a painless transition to spread these facts out into proper tables,
as we figure out which facts are relevant\.

```sql
CREATE TABLE run_action_copy (
   run_action_id INTEGER PRIMARY KEY AUTOINCREMENT,
   class TEXT CHECK (length(class) <= 3),
   time DATETIME DEFAULT (strftime('%Y-%m-%dT%H:%M:%f', 'now')),
   round INTEGER,
   run INTEGER NOT NULL,
   fact LUATEXT,
   FOREIGN KEY (run)
      REFERENCES run (run_id)
      ON DELETE CASCADE
   FOREIGN KEY (round)
      REFERENCES round (round_id)
);
```

We could also decorate `run` with a `fact` row, I would rather hash out what
we should always make notice of and add a bucket taxon if it actively looks
like we need one\.

As I've mentioned, the strategy for ensuring ordinality should be different,
I've added a row\_id and we'll solve this problem later, but once and for all\.

This is a good time to mention other responses, such as:


#### error

Which we split into `error` and `error_text`:

```sql
CREATE TABLE error_text (
   error_line_id INTEGER PRIMARY KEY,
   error TEXT UNIQUE NOT NULL,
   hash TEXT NOT NULL -- trust me, SQLite: it's UNIQUE
); -- index me
```

```sql
CREATE TABLE error(
   error_id INTEGER PRIMARY KEY,
   response INTEGER, -- NOT NULL? maybe
   short INTEGER,
   error INTEGER NOT NULL,
   FOREIGN KEY response
      REFERENCES response (response_id)
   FOREIGN KEY error_text
      REFERENCES error_text (error_text_id)
   FOREIGN KEY short
      REFERENCES error_text(error_text_id)
);
```

The `short` form for errors will be a work in progress, so I think it's best
to have it as an optional second pointer: we might want to go through and
rewrite all the short forms to use a better algorithm, so that any sessions
based on primitive short\-form equality \(which is much of the point of having
it\) will have a fighting chance of updating correctly\.

Given how error reporting works, if a short form happens to be the identical
string to a full error text, then yeah, those are the same thing\. It's valid
that they both point to the same table\.


#### status\_response

If a round has no results nor an error, it must have a status\.

Examples which might make it into the database are: `'pending'` for an event
which yielded and expects a response, and `'yielded'` if it just yielded\.

The list is not exhaustive, and this is a good example of why we make rounds
stateless, not unique: a `'pending'` round might have a new *response*, in
the form of results, so we have to know to make a new Round even if we have
an existing round with a response of status pending, so we can update the
response pointer\.

This implies that this table will be somewhat shallow: we certainly don't
need multiple responses per response status,

```sql
CREATE TABLE status_response(
   status_response_id INTEGER PRIMARY KEY,
   response INTEGER NOT NULL,
   category TEXT NOT NULL,
   FOREIGN KEY response
      REFERENCES response (response_id)
);
```


#### session

The session contains the session data, and a pointer to the riff\.

Premises, in turn, point 'through' the riff, directly at the associated riff
round, as well as at the associated session\.

Note the expansion field `doc`, which can be a foreign key across to the
`orb` database\.

The idea is that we will export mature sessions as Orb documents, and the
session machinery will keep track of the state of the important parts of that
document, but not using this database\.

`session` also has a `fact` table, for the same open\-ended expansion purposes
as runs\.  In this case, we might have a map of require strings to their latest
hash, so we can retrieve and run any sessions if those modules change\.

The `accepted` column is now called `active`\.

```sql
CREATE TABLE session_copy (
   session_id INTEGER PRIMARY KEY,
   title TEXT,
   doc INTEGER,
   doc_hash TEXT,
   project INTEGER,
   active INTEGER NOT NULL DEFAULT 0 CHECK (active = 0 or active = 1),
   riff INTEGER NOT NULL,
   fact LUATEXT,
   FOREIGN KEY (project)
      REFERENCES project (project_id)
   FOREIGN KEY (riff)
      REFERENCES riff (riff_id)
);
```


#### premise

This is now a pointer into a riff **round**, with additional metadata\.

The riff round enforces order in the riff, which premise need not duplicate\.

To keep everything shipshape, the tuple `(premise_id, riff_round)` is kept
unique\.

Note that the premise table also has a premise column, which used to be called
the title\.  This is part of why we call the rowid of `thing` `thing_id`: it
means we can have `thing.thing`, and always refer to `thing.thing_id` as just
`thing_id`, since `other.thing` will always be the name for the thing **id** on
another table\.

We rename the 'reject' status to 'watch', to properly reflect the intention\.

The new premise table also has a boolean, `normal`, which is true/1 by default\.

This value ignored in status `'ignore'`, but should be 1 under such conditions\.

For `'accept'`, a false indicates a failing test, for `'watch'`, one which
differs from its expected result\.

```sql
CREATE TABLE premise_copy (
   premise_id INTEGER PRIMARY KEY,
   session INTEGER NOT NULL,
   riff_round INTEGER NOT NULL,
   premise INTEGER NOT NULL,
   normal INTEGER CHECK (normal = 0 OR normal = 1) DEFAULT 1,
   status STRING NOT NULL CHECK (
      status = 'accept' or status = 'watch' or status = 'ignore' ),
   FOREIGN KEY (session)
      REFERENCES session (session_id)
   FOREIGN KEY (riff_round)
      REFERENCES riff_round (riff_round_id)
   FOREIGN KEY (premise)
      REFERENCES line (line_id)
);
```


### Migration 7: the migration\.

This will be gnarly, but breaks down into stages\.


#### Refactor helm\-db

  I'll move all the historical migrations into their own file, start one for
migration\-7, and rebuild helm\-db in terms of the arcive\.

May as well collapse the history into a schema snapshot, since I'm quite
confident they'll never be applied again\.


##### re\-hash: affects repr, result

  I used a hybrid of hashing and raw comparison for uniques in various places,
the tradeoff being less storage \(meh\) and allocation \(that was the one\) for
an inconsistent representation\.

This was too clever by half\.  We were also truncating full SHA\-512 hashes,
instead of using the preferred SHA\-512/256 form for truncation\.  This doesn't
harm the security properties, but there's no advantage to using a nonstandard
hash here\.


##### dissolve input table

This is where ~all the logic lives\.

We need to take inputs and responses to them, synthesize them into rounds,
make up some runs from the era before those existed, and turn the inputs into
run actions, the rounds into riffs, and so on\.

The advantage of how data is currently arranged is that we can do mega\-queries
which give us everything associated with a row, and use that to put things
where they belong\.

```sql
SELECT
   input.line as line,
   input.time as time,
   premise.session as session_id,
   premise.ordinal as premise_order,
   premise.title as premise,
   premise.status as status,
   result.hash as shorthash,
   repr.repr as repr,
   run_action.run as run_id
FROM
   input
LEFT JOIN premise on premise.line = input.line_id
LEFT JOIN result on result.line_id = input.line_id
LEFT JOIN repr on result.hash = repr.hash
LEFT JOIN run_action on run_action.input = input.line_id
WHERE
   project = :project_id
;
```


#### mutate premise status

Swaps 'reject' for 'ignore'\.


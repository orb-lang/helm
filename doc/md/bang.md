# bang!


We have, at present, two input modes for ``modeselektor``: the normal mode,
``nerf``, and a companion mode we've called [search](hts://~/search.orb).


We could also call this ``/`` mode, pronounced "slash", and it is familiar to
the vim-conversant.


The next mode we sketch, and build, is ``bang``.  This is a short-imperative
form in a shell sort of idiom.


An example:

```bang
! orb spec
```

would run ``orb spec``. The space is optional, ``!orb spec`` is fine.


``bang`` mode is stateful so the next command could be

```bang
!@ agenda
```

where ``@`` simply means last noun.

# Painter


The ``modeselektor`` module responsible for display.


``femto`` is currently both the loop loader and the inbox, and I will eventually
break the latter out into its own module.  In any case, it wholly owns
``stdin``, ``modeselektor`` runs entirely on messages.


``painter`` receives a ``rainbuf`` and a ``region``.  ``modeselektor`` triggers the
creation of ``rainbuf``s and ``region``s; the former is write-owned by
``modeselektor``, the latter write-owned by ``painter``.


First thing we're going to do with ``painter`` is encapsulate all existing use
of ``stdout``.

```lua

```

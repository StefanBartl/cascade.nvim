# cascade.nvim features

Four domains under one roof, separated by *what has to be recognised first*:

| Domain | Scope | Does |
| --- | --- | --- |
| **lists** | `lists.filetypes` | Continue lists, renumber them, tick checkboxes, cycle marker types, indent/dedent, move lines |
| **cycle** | global | Advance the token under the cursor — `true`→`false`, an ISO date, a lone letter, an operator — via `<C-y>`/`<C-x>` or `+`/`-`, with a native fallback for numbers |
| **sequence** | global | Renumber the ordinals (`1.`, `a)`, `II.`) *inside* a Visual selection, whatever precedes them: numbered headlines, inline numbers in prose |
| **transpose** | global | Swap a character or a word (or a same-line selection) with its neighbor, UTF-8 safe |

The separation is not cosmetic. A list operation has to know it is in a list
before it can do anything; a cycle operation only has to know what is under
the cursor. Mixing the two produces a plugin that either refuses to work
outside Markdown or corrupts code that happens to start with a dash. See
[architecture.md](../architecture.md) for the pure-line-scan default this
follows from.

- **[CYCLE.md](CYCLE.md)** — advancing the token under the cursor one step in
  either direction: a word or boolean, an ISO date segment, a numeric value,
  an operator. Global by default, because `true`↔`false` is worth having in
  `.lua`, `.md` and `.txt` alike; `cycle.filetypes` narrows it.
- **[LISTS.md](LISTS.md)** — everything that recognises a list marker and
  advances it: continuation, renumbering, checkbox cycling, changing a
  marker's shape, block transforms, and level-aware indent and move. Scoped to
  `lists.filetypes`, and a line with no recognised marker is always a no-op —
  which is what makes a broad filetype list safe.
- **[SEQUENCE.md](SEQUENCE.md)** — renumbering the ordinal tokens in a
  *selection*, whatever precedes them. Its own feature rather than part of
  lists, and for a structural reason: the list parser requires the number to
  be the line's first token, so a numbered headline is invisible to it.
- **[TRANSPOSE.md](TRANSPOSE.md)** — swapping a character, a word, or a
  same-line Visual selection with its neighbour. UTF-8 safe, and global with
  no filetype option at all, because swapping two characters does not depend
  on what language they are in.

Every feature can be switched off on its own: the keys are in
[BINDINGS.md](../BINDINGS.md), the option that gates each one is in
[configuration.md](../configuration.md), and how they combine day to day is in
[WORKFLOW.md](../WORKFLOW.md).

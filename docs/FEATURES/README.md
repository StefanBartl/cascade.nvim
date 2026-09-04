# cascade.nvim features

Four areas, and what separates them is **what the plugin has to recognise
first**. Cycling and transposing look at one token and work in any filetype;
lists need a marker and are therefore scoped; renumbering a selection sits
deliberately outside the list parser, because that parser cannot see the case
it is for.

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

# Roadmap

---

## Shipped

### Sequence domain — renumbering inside a selection

Renumbers the ordinal tokens (`1.`, `a)`, `II.`) inside a Visual selection,
whatever precedes them — the two cases `lists.renumber` structurally cannot
reach, because `lists/marker.lua` requires the number to be the line's first
token:

1. numbered Markdown headlines (`### 2. iwas`), only the selected block;
2. plain inline numbers in prose, selected mid-line, in any filetype.

Built as its own domain (`lua/cascade/sequence/renumber.lua`, config key
`sequence`) rather than as an extension of the list renumberer, analogous to
`cycle`/`transpose`: global, filetype-independent, no `marker.parse`.

- Keymap `<leader>cR` (Visual only — an Ex range `:'<,'>` is always linewise
  and would discard the columns a mid-line selection needs).
- `:Cascade renumber selection` as the Ex pendant for the linewise case.
- Options: `sequence.enable`, `sequence.start` (`"keep"`/`"one"`),
  `sequence.types` (kind order for the first hit, which locks the kind).
- Docs: [`docs/FEATURES/SEQUENCE.md`](../FEATURES/SEQUENCE.md),
  `:h cascade-sequence`. Specs: `docs/TESTS/sequence_spec.lua`.

## Deferred

- **Multi-line charwise selections.** `lib.nvim.selection.chars()` returns
  `nil` as soon as the selection spans rows, so a charwise selection across
  several lines is handled as a whole-line range. Both motivating cases above
  are covered without it. If the need becomes real, the fix belongs in
  `lib.nvim` (a `chars_multiline()`), not rebuilt cascade-locally.

---

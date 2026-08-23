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
  and would discard the columns a mid-line or multi-line selection needs).
- `:Cascade renumber selection` as the Ex pendant for the linewise case.
- Options: `sequence.enable`, `sequence.start` (`"keep"`/`"one"`),
  `sequence.types` (kind order for the first hit, which locks the kind).
- Docs: [`docs/FEATURES/SEQUENCE.md`](../FEATURES/SEQUENCE.md),
  `:h cascade-sequence`. Specs: `docs/TESTS/sequence_spec.lua`.

### Multi-line charwise selections

Closed the gap this domain shipped with deferred: `lib.nvim.selection.chars()`
only ever covered a same-line charwise selection, so a charwise selection
spanning several lines fell back to the whole-line (linewise) path.

- `lib.nvim.selection` gained `chars_multiline()` /
  `reselect_chars_multiline()` / `keep_chars_multiline()` — same 0-based,
  explicit-bounds contract as `lines()`/`chars()`, added there (not forked
  cascade-locally) per the standing "extend lib.nvim" policy. Specs:
  `lib.nvim`'s `docs/TESTS/selection_spec.lua` (new file — no prior spec
  covered this module at all).
- `sequence/renumber.lua` gained `M.span_multi`: the first line's selected
  part runs to its end, every full line in between is entirely selected, the
  last line's selected part runs from its start through the selection end —
  matching exactly what Vim considers "selected" for a multi-line charwise
  span. Text outside those bounds, on either boundary line, is untouched.
- `cascade.util.lib` bridges the new pair directly to `lib.nvim.selection`
  (no standalone fallback, unlike `lines`/`chars`/`keep_lines`/`keep_chars`
  below them in the same file) — `lib.nvim` is cascade's one *required*
  dependency, and duplicating a fresh ~40-line feedkeys implementation here
  would only fork what was just added upstream for this exact purpose.
- `renumber_selection` now tries same-line charwise, then multi-line
  charwise, before falling back to the linewise range.

---

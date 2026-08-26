# Sequence

Renumbers the ordinal tokens (`1.`, `a)`, `II.`) **inside a selection**,
whatever precedes them — global, filetype-independent, no list context
required. This is the case `lists.renumber` structurally cannot see:
`lists/marker.lua`'s parser requires the number to be the very first token
of the line, so a numbered Markdown headline (`### 2. iwas`) or a number
sitting mid-sentence in prose is invisible to it.

Both motivating cases are the same operation — scan the selected text for
ordinal tokens in order of appearance, rewrite them sequentially — which is
why this is its own domain (like `cycle`/`transpose`) rather than an
extension of the list renumberer.

```md
### 7. keep me           (outside the selection — untouched)
### 2. iwas          ─┐
prose in between      │  selected, then <leader>cR:
### 3. sad            │  2. / 3. / 9.  ->  2. / 3. / 4.
### 9. more          ─┘  ("keep": the first hit sets the start value)
### 4. keep me too       (outside the selection — untouched)
```

```txt
te 4. text der nur als 5. beispiel 9. um wa
   ->  te 4. text der nur als 5. beispiel 6. um wa
```

## What counts as an ordinal

- **Module:** `sequence/renumber.lua` (the scanner)
- **Config:** `sequence.types` — which kinds are recognized

An alphanumeric run followed by `.` or `)`. Two boundary rules keep the
scanner out of ordinary prose:

- the run is matched **greedily**, so the `1` in `v1.2` is never seen on its
  own;
- the delimiter must be followed by whitespace or end-of-text, so decimals
  (`3.14`) and abbreviations (`e.g.`) don't qualify.

## Kind lock

- **Module:** `sequence/renumber.lua`
- **Config:** `sequence.types` (default order: `digit`, `ascii`, `roman`)

The **first** hit decides whether the run is `digit`, `ascii` or `roman` —
tried in the order of `sequence.types` — and locks it. Tokens of the other
kinds are then skipped rather than folded into the same sequence, so an
`a)` sitting inside a block of numbered items is left alone.

Single letters are read as `ascii` before `roman` by default (`a)b)c)` is
the commoner case); put `"roman"` first for `i./ii./iii.` sequences.
Multi-letter alphabetic tokens are only ever read as Roman numerals, and
the conversion validates by round-trip, so a word like `so.` is rejected.

Case follows the token being replaced (`ii.` → `iii.`, `II.` → `III.`), and
the delimiter is kept **per hit** — a mixed `.`/`)` selection keeps its
shapes, only the number is replaced.

## Selection handling

`renumber_selection` is Visual mode only, on purpose: an Ex-command range
(`:'<,'>`) is always linewise in Vim and would discard the columns a
mid-line charwise selection needs.

- **charwise (`v`), same line** — rewritten in place with
  `nvim_buf_set_text`, so the rest of the line is untouched, and reselected
  on its new bounds (the text can widen, `9.` → `10.`).
- **charwise (`v`), across several lines** — the first line's selected part
  runs from the selection start to its end, every line strictly in between
  is entirely selected, and the last line's selected part runs from its
  start through the selection end — exactly what Vim itself considers
  "selected" for a multi-line charwise span. Untouched text before the
  start (first line) and after the end (last line) passes through as-is;
  the running counter carries across the whole span. Rewritten with
  `nvim_buf_set_lines` and reselected on its new bounds via
  `lib.nvim.selection.chars_multiline`/`reselect_chars_multiline`.
- **linewise (`V`), or a selection with no column bounds at all
  (blockwise)** — treated as a whole-line range and reselected linewise.

```md
before ### 7. keep me      (before the selection start — untouched)
### 2. iwas          ─┐
prose in between      │  selected mid-line on both ends, then <leader>cR:
### 9. sad tail      ─┘  2. / 9.  ->  2. / 3.  ("sad" in, " tail" stays out)
```

- **Module:** `sequence/renumber.lua` (`M.rewrite`, `M.range`, `M.span`, `M.span_multi`)
- **Config:** `sequence.enable`, `sequence.start`, `sequence.types`
- **Keymaps:** `<leader>cR` (global, Visual, preset)
- **Command:** `:Cascade renumber selection` (linewise pendant, range-aware)
- **lib.nvim:** `lib.nvim.selection.chars_multiline`/`reselect_chars_multiline`
  (the multi-line charwise capture/reselect primitives cascade's `util/lib.lua`
  bridges to directly)

## Options

- **Module:** `config/init.lua` (`normalize_sequence`)
- **Config:** `sequence.enable`, `sequence.start`, `sequence.types`

| Option | Values | Meaning |
| ------ | ------ | ------- |
| `sequence.enable` | boolean | Master switch for the domain. |
| `sequence.start` | `"keep"` \| `"one"` | `keep` (default) takes the start value from the first hit, like `lists/renumber.lua`; `one` always restarts at `1`/`a`/`i`. |
| `sequence.types` | `string[]` | Kinds tried, in order, to classify the first hit: `"digit"`, `"ascii"`, `"roman"`. |

Malformed values degrade to the documented defaults instead of erroring
mid-scan (`config/init.lua`'s `normalize_sequence`).

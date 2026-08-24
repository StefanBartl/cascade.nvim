# Lists

Everything that detects a list marker under the cursor (or in a block/visual
selection) and advances it: continuation, renumbering, checkbox cycling,
marker-shape changes, block transforms, and level-aware indent/move. Scoped
to `lists.filetypes` (Markdown, org, norg, LaTeX, reStructuredText, …) — a
line with no recognized marker is always a no-op, so a broad filetype list
is harmless. Each feature can be switched off individually via
`lists.features.*`.

## Continuation

`<CR>` in insert mode, `o`/`O` in normal mode insert the next bullet,
incrementing ordered markers. `<CR>` on an already-empty bullet deletes it
and ends the list instead of continuing it.

- **Module:** `lists/continue.lua` (`M.cr`, `M.o`, `M.O`)
- **Config:** `lists.features.continue`, `lists.continue.delete_empty`
- **Keymaps:** [`../BINDINGS.md#preset-keymaps`](../BINDINGS.md#preset-keymaps) (`<CR>`/`o`/`O`)

## Renumber

Re-sequences an ordered list block, respecting a start offset that isn't 1.
Runs automatically on `"edit"` (immediately after indent/move/continue) and
`"save"` (`BufWritePre`, whole buffer) per `lists.renumber.on`, or manually
via `:Cascade renumber` / `<leader>cr`. A non-marker, non-blank line (a
wrapped paragraph or note) never breaks the sequence — matches Markdown's
"lazy continuation" reading. A blank line ends the block unless
`lists.renumber.blank_break` is raised.

- **Module:** `lists/renumber.lua` (`M.at`, `M.all`, `M.tree`, `M.run`)
- **Config:** `lists.renumber.enable`, `lists.renumber.on`, `lists.renumber.blank_break`
- **Usercmds:** [`../BINDINGS.md#user-commands`](../BINDINGS.md#user-commands) (`:Cascade renumber [all]`)

## Checkbox cycle

Cycles the checkbox under the cursor through a configurable N-state
sequence (`[ ]` → `[x]` → …, wrapping around). Dot-repeatable.
Multi-byte states (e.g. emoji) work if listed in `lists.checkbox.states`.

- **Module:** `lists/checkbox.lua` (`M.toggle`)
- **Config:** `lists.features.checkbox`, `lists.checkbox.states`
- **Keymaps:** `<leader>cx` (preset, buffer-local)

## Quick bullet toggle

Turns any line into a `-` (or `*`) bullet and back, without requiring an
existing marker — unlike checkbox/cycle_type, which only ever advance one.
Works on a Visual/Visual-line selection too, each line toggled
independently. Dot-repeatable.

- **Module:** `lists/quick_toggle.lua` (`M.bullet`, `M.star`, `M.bullet_range`, `M.star_range`)
- **Config:** `lists.features.bullet_toggle` (also gates `<A-->`/`<A-*>`)
- **Keymaps:** `<A-->` / `<A-*>` (normal + visual, preset, buffer-local)

## Quick number toggle

Turns any line into a `1.` numbered marker and back, without an existing
marker required, renumbering against its siblings once inserted.
Dot-repeatable, visual-range variant included.

- **Module:** `lists/quick_toggle.lua` (`M.number`, `M.number_range`)
- **Config:** `lists.features.number_toggle`
- **Keymaps:** `<A-0>` (normal + visual, preset, buffer-local)

## Quick checkbox toggle

Cycles a `- [ ]` checkbox on any line: inserts it from scratch, cycles
through `lists.checkbox.states`, then removes it again after the last
state. Dot-repeatable, visual-range variant included.

- **Module:** `lists/quick_toggle.lua` (`M.checkbox`, `M.checkbox_range`)
- **Config:** `lists.features.checkbox_toggle`
- **Keymaps:** `<A-c>` (normal + visual, preset, buffer-local)

## Cycle list type

Steps the marker at the cursor forward/backward through
`lists.cycle` (default `- * + 1. a) I.`). Dot-repeatable.

- **Module:** `lists/cycle_type.lua` (`M.cycle`)
- **Config:** `lists.features.cycle_type`, `lists.cycle`
- **Keymaps:** `<leader>ct` / `<leader>cT` (preset, buffer-local)

## Form rotation

Rotates a whole block (or Visual selection) through the forms configured
in `lists.forms` — a form combines a marker shape with an optional `[ ]`
checkbox. Default sequence: `1.` → `1. [ ]` → `- [ ]` → `-`. Existing
checkbox states are preserved while rotating; ordered targets are
renumbered automatically. Dot-repeatable (normal), range-aware
(`:Cascade rotate`).

- **Module:** `lists/transform.lua` (`M.rotate`)
- **Config:** `lists.features.rotate`, `lists.forms`
- **Keymaps:** `<leader>cf` / `<leader>cF` (preset, buffer-local, normal + visual)
- **Usercmds:** `:Cascade rotate [next|prev]` (`!` = backward)

## Sort A-Z

Sorts a block/selection alphabetically and renumbers it. Range-aware,
dot-repeatable (normal).

- **Module:** `lists/transform.lua` (`M.sort`)
- **Config:** `lists.features.sort`
- **Keymaps:** `<leader>cs` (preset, buffer-local, normal + visual)
- **Usercmds:** `:Cascade sort` (`!` = Z-A)

## Reverse order

Reverses a block/selection and renumbers it. Range-aware, dot-repeatable
(normal).

- **Module:** `lists/transform.lua` (`M.reverse`)
- **Config:** `lists.features.reverse`
- **Keymaps:** `<leader>cv` (preset, buffer-local, normal + visual)
- **Usercmds:** `:Cascade reverse`

## Strip checkbox

Strips `[ ]`/`[x]` from every item in a block/selection while leaving the
marker itself in place. Range-aware, dot-repeatable (normal).

- **Module:** `lists/transform.lua` (`M.strip`)
- **Config:** `lists.features.strip`
- **Keymaps:** `<leader>cX` (preset, buffer-local, normal + visual)
- **Usercmds:** `:Cascade strip`

## Indent / dedent

Level-aware: indenting/dedenting a numbered list renumbers every level a
change touches (a deeper level starts fresh at `1.`, a shallower level
continues, the level left behind closes its gap). A single line carries
its subtree (nested children, wrapped continuation text) along with it.
Outside `lists.filetypes` it is a plain `>>`/`<<`. Global keymaps
(`<A-Right>`/`<A-Left>`), `vim.v.count` means "how many lines" (one level
each); `<leader><A-Right>`/`<leader><A-Left>` shift a single line by `N`
levels instead.

- **Module:** `lists/indent.lua` (`M.shift_line`, `M.shift_range`)
- **Config:** `lists.features.indent`
- **Keymaps:** `<A-Right>`/`<A-Left>` (global, all modes), `<leader><A-Right>`/`<leader><A-Left>` (levels variant)
- **Usercmds:** `:Cascade indent [n]` / `:Cascade dedent [n]`

## Move lines

Moves a line or selection up/down, reindenting it (`==`) and renumbering
the affected list block; outside a list it's a plain `:move` + reindent.

- **Module:** `lists/move.lua` (`M.line`, `M.selection`)
- **Config:** `lists.features.move`
- **Keymaps:** `<A-Up>`/`<A-Down>` (global, normal/visual/insert)

## Roman & alpha markers

Converts between integer position and `I. II. III.` (roman) or `a) b) c)`
(alpha) marker text, cleanly encapsulated for use by the marker parser and
renumberer. Opt-in via `lists.types` (ambiguous with plain letters, so not
on by default); order in `types` decides when several kinds are enabled.

- **Module:** `lists/roman.lua` (`M.to_roman`, `M.to_int`), `lists/alpha.lua` (`M.to_int`, `M.to_alpha`)
- **Config:** `lists.types` (`"ascii"`, `"roman"` opt-in alongside `"unordered"`/`"digit"`)

## Custom per-filetype markers

Non-incrementing marker patterns tried before the built-in kinds
(unordered/digit/ascii/roman) — e.g. LaTeX's `\item`, which is none of
those. Each pattern needs exactly two Lua-pattern captures: the marker
token, then the rest of the line after the separating whitespace. Matches
are always treated as an "unordered" kind (fixed token, never renumbered).

- **Module:** `lists/marker.lua` (`M.parse`)
- **Config:** `lists.per_filetype_patterns`

## Hanging-indent formatting

Sets buffer-local `formatlistpat` (derived from `lists.types`/
`lists.unordered_markers`) and adds `n` to `formatoptions` on the
configured list filetypes, so native `gq`/auto-wrap hang-indents a wrapped
item under its text instead of back at the margin.

- **Module:** `lists/format.lua` (`M.list_pat`, `M.apply`)
- **Config:** `lists.continue.hanging_indent`

## Treesitter precision (opt-in)

Pure line scan by default — no Treesitter dependency, blind to syntax.
`lists.precision = "treesitter"` additionally skips single-cursor list
actions (continuation, toggles, single-line indent, …) when the cursor
sits inside a configured "skip" node (default: a fenced code block in
Markdown/norg), catching the one real edge case a plain scan can't: a
shell `- flag` or Python `# 1. note` inside a fenced block that merely
*looks* like a list marker. Every check is `pcall`-wrapped — a missing or
broken parser falls back to "not inside a skip node", never breaks the
default behavior. Range/whole-buffer operations (visual shifts, `:Cascade`
commands, save-time renumber-all) are not gated this way, since "inside a
skip node" isn't well-defined for an arbitrary range.

- **Module:** `core/treesitter.lua` (`M.in_skip_node`)
- **Config:** `lists.precision` (default `"off"`), `lists.precision_nodes`

## Right-click context menu (nvzone/menu)

`cascade.integrations.menu` contributes the normal-mode subset of the list
actions above (checkbox, cycle type, renumber, rotate, sort, reverse,
strip) as entries in the shape [nvzone/menu](https://github.com/nvzone/menu)
expects, gated the same way the keymaps are: `lists.enable`, the buffer's
filetype being in `lists.filetypes`, and each `lists.features.*` flag.
Global presets (cycle/sequence/transpose) are deliberately excluded —
cursor-position-driven, they don't compress into discrete menu items.
cascade.nvim has no dependency on `menu` and never opens a context menu
itself — a host (typically your own `<RightMouse>` dispatcher) composes
the entries into its own menu.

- **Module:** `cascade/integrations/menu.lua` (`M.items`, `M.submenu`)
- **Docs:** [`../BINDINGS.md#context-menu-optional`](../BINDINGS.md#context-menu-optional)

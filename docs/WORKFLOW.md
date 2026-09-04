# Workflow — getting real use out of cascade.nvim day to day

Every feature here is documented on its own in
[`docs/FEATURES/`](FEATURES/) (`LISTS.md`, `CYCLE.md`, `SEQUENCE.md`,
`TRANSPOSE.md`) and
[`docs/BINDINGS.md`](BINDINGS.md). This is the different question: once the
three domains exist side by side, *how do they actually combine* into
something worth reaching for while editing, not just something bound to a
key you forget about.

## Install with the preset, not piecemeal

`require("cascade").setup({ keymaps = { preset = true } })` binds
everything at once — global cycle/transpose, buffer-local list keys in
`lists.filetypes`. There is no in-between "turn on lists only" install
step: without `keymaps.preset = true`, `setup({})` binds nothing at all,
and every action still has to be wired by hand via `vim.keymap.set`. If
you want the preset's global word/number cycle in `.lua`/`.ts` files too
(not just prose), load with `event = "VeryLazy"`, not `ft = { ... }` —
`ft`-scoped loading means the plugin (and its global cycle) doesn't exist
yet outside those filetypes. The trade-off per loading strategy is laid out
in [`installation.md`](installation.md#which-loading-strategy).

`lib.nvim` is a **required** dependency, not a soft one: without it,
`:Cascade` fails to load outright (`lib.nvim.bindings.usercmd.composer` builds the
command). `lib.map`/`lib.notify` stay soft — used when present, native
fallback otherwise. `:checkhealth cascade` is the fast way to confirm
which of the two situations you're in before assuming a missing command is
a cascade bug.

## The one habit worth building: let `<CR>`/`o`/`O` do the counting

Once `keymaps.preset = true` is set in a list filetype, stop typing marker
numbers by hand. `<CR>` at the end of `3. foo` inserts `4. bar` for you;
typing `1.` yourself out of habit is what `lists.renumber.on = { "edit",
"save" }` (the default) is there to quietly fix afterward, not what it's
for. The real payoff shows up when reordering: `<A-Up>`/`<A-Down>` moves a
line or Visual block and renumbers around the move in the same step,
which manual editing never keeps in sync.

## `<A-Right>`/`<A-Left>`: the count meaning changed under a numbered list

This is the one genuine trap in the binding surface. `N<A-Right>` shifts
`N` *lines* starting at the cursor, one level each — for promoting a run
of sibling items at once:

```
1. one              1. one
2. two     2<A-Right>  1. two    ← 2 lines, one level each
3. three            2. three
```

To shift a *single* line by `N` **levels** instead (the meaning the plain
count used to have), the mapping moved to `<leader><A-Right>` /
`<leader><A-Left>`: `2<leader><A-Right>` promotes the current line two
levels in one go. Muscle memory from before this split will reach for the
wrong one under time pressure — if a promote looks like it "moved too many
lines" instead of "moved too many levels", that's the tell.

## Form rotation vs. manual find-and-replace

`<leader>cf` (or `:Cascade rotate`) turns a whole numbered checklist into
a plain bullet list — `1.` → `1. [ ]` → `- [ ]` → `-` — in one rotation
per step, block- or selection-wide, checkbox state (`[x]`) preserved
across the change. Reach for this instead of a `:s` substitution whenever
the *shape* of a list is changing (numbered todo → plain notes, say), since
substitution won't renumber the ordered forms it produces and won't touch
only the block under the cursor without a manual range.

## `:Cascade` bang binds to the verb, not the subcommand

`:Cascade! rotate` (not `:Cascade rotate!`) — collapsing the old
per-action commands (`:CascadeRotate`, `:CascadeSort`, …) into one
`:Cascade <subcommand>` moved the bang to where Vim's parser actually
expects it, on the command name itself. `:Cascade sort` / `:Cascade!
sort` is the A–Z / Z–A pair; the un-negatable ones (`reverse`, `strip`,
`indent`, `dedent`, `renumber`) simply ignore a bang if you type one.

## Global vs. filetype-scoped: don't expect lists behavior outside prose

Only `lists` (continue, checkbox, cycle_type, rotate, sort, reverse,
strip, renumber) is scoped to `lists.filetypes`. `cycle` and `transpose`
are global by default — `<C-y>`/`<C-x>` toggling `true`↔`false` and
`<leader><Right>` swapping two characters both work in a `.lua` buffer out
of the box, with no config needed. The direction people get surprised by
in practice is the other one: expecting `<CR>` to continue a list inside a
code comment, which it never will unless that filetype is added to
`lists.filetypes` — list actions no-op on any line without a recognized
marker, comment or not.

| Domain | Scope | Typical surprise |
| --- | --- | --- |
| `lists` (continue, checkbox, rotate, sort, …) | `lists.filetypes` only | Expecting it in code buffers |
| `cycle` (word/boolean, numbers, dates, letters, in-word chars) | global (`filetypes = nil`) | Not expecting it outside prose |
| `transpose` (char/word swap) | global, no filetype option at all | — |
| Indent/dedent, move | global; renumber only inside `lists.filetypes` | Renumbering silently skipped outside prose (correct — it's just `>>`/`<<`) |

## Cycle packs: the order you list them is the tie-breaker

`cycle.packs` is a list, and that list is a precedence order, not a set. It
matters as soon as two enabled languages share a word — `no` is both English
and Spanish, `ja` is both German and Dutch, `falso` is both Spanish and
Italian. A word belongs only to the *first* group containing it, so
`{ "en", "es" }` makes `no` cycle to `yes` and `{ "es", "en" }` makes it cycle
to `sí`. Put your primary language first.

The shipped default (`{ "en", "de", "dev" }`) is collision-free, so this only
becomes a question once you add packs. `:checkhealth cascade` lists exactly
which words your combination makes unreachable, rather than leaving you to
discover it on a keypress that silently does the wrong thing.

Anything in `cycle.groups` outranks every pack, which is the intended way to
override a single pair without disabling a whole language.

## Turning a feature off vs. rebinding it

`lists.features.rotate = false` (etc.) is not the same as just not binding
the key — a disabled feature makes the *action itself* a no-op, so a key
you bound manually via Variant B (`vim.keymap.set("n", "<leader>cf",
cascade.rotate_form_next)`) would also silently do nothing. If a mapping
feels dead, check `lists.features.*`/`cycle.features.*`/
`transpose.features.*` before assuming the keymap itself is wrong —
`:checkhealth cascade` reports enabled/disabled per domain, though not yet
per individual feature.

## Treesitter precision: turn it on only if you write fenced code inside prose

`lists.precision = "off"` (the default) is a pure line scan — fast,
no parser dependency, and blind to one edge case: a shell `- flag` or a
Python `# 1. note` inside a fenced code block in a Markdown/norg file
looks exactly like a real list marker to a line scan, so `<CR>` will try
to continue it. `lists.precision = "treesitter"` fixes exactly that case
by skipping single-cursor list actions inside a fenced block — worth
turning on only if your Markdown notes actually contain fenced snippets
with lines that start with `-` or a digit-dot; a fallback to "off"
behavior is automatic (via `pcall`) if the filetype has no Treesitter
parser installed, so turning it on for a filetype you don't have a parser
for costs nothing but also fixes nothing.

## `+`/`-` are shared: date, word cycle, letter, number, then native line motion

Binding `+`/`-` (as the preset does) layers five behaviors on one pair of
keys, tried in this order: an ISO date under the cursor steps its
year/month/day segment; failing that, a matching word/boolean group
cycles; failing that, a lone a-z/A-Z letter steps through the alphabet
(case preserved, e.g. `a` → `b`, `Z` → `A`); failing that, a plain number
falls back to native `<C-a>`/`<C-x>`; failing all four, `+`/`-` do what Vim
always did with them — move to the first non-blank of the next/previous
line. Nothing needs configuring for this chain to make sense, but it
explains why `+` on an arbitrary line without a date, group word, letter,
or number "does nothing special" — that's it correctly falling through to
native, not a bug.

## …and `<C-M-y>`/`<C-M-x>` are the deliberate exception to that chain

The chain above is dictionary-driven, which has one consequence worth naming:
a lone `a` cycles, but the `a` inside `cat` does not. The token under the
cursor is `cat`, no group contains it, so the key falls through to native —
correct, and occasionally not what you wanted.

`<C-M-y>`/`<C-M-x>` are that other intent, on their own keys: step the
character under the cursor, no lookup, no word boundary. They are *not* a
sixth link in the `+`/`-` chain on purpose — a final "nothing matched, so
edit the character" step would rewrite text on every unknown word, turning
the one thing the chain guarantees (an unknown word is left alone) into a
coin flip. Two intents, two keys.

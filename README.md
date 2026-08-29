```
                                       __
   _________ _______________ _____/ /__
  / ___/ __ `/ ___/ ___/ __ `/ __  / _ \
 / /__/ /_/ (__  ) /__/ /_/ / /_/ /  __/
 \___/\__,_/____/\___/\__,_/\__,_/\___/
        context-aware lists & cycling
```

[![CI](https://github.com/StefanBartl/cascade.nvim/actions/workflows/ci.yml/badge.svg)](https://github.com/StefanBartl/cascade.nvim/actions/workflows/ci.yml)
![Neovim](https://img.shields.io/badge/Neovim-0.9+-57A143?logo=neovim&logoColor=white)
![Lua](https://img.shields.io/badge/Made%20with-Lua-2C2D72?logo=lua&logoColor=white)

> 💡 Pairs well with [pickers.nvim](https://github.com/StefanBartl/pickers.nvim):
> use cascade to shape and renumber the lists inside a file, and pickers.nvim to
> jump between the files that hold them.

> One plugin, one pattern: **detect the context under the cursor → advance it one
> step → otherwise fall back to native behavior.** That holds for Markdown lists
> just as much as for `true`/`false` toggles in code.

`cascade.nvim` unites four feature worlds under one roof:

- **lists** — continue lists, renumber them, tick checkboxes, cycle marker
  types, indent/dedent (filetype-scoped).
- **cycle** — advance the word under the cursor (`true`→`false`, `on`→`off`, …)
  via `<C-y>`/`<C-x>` or `+`/`-`, with a native fallback for numbers and,
  off `+`/`-`, for the plain line motion (global).
- **sequence** — renumber the ordinals (`1.`, `a)`, `II.`) *inside* a Visual
  selection, whatever precedes them: numbered headlines, inline numbers in
  prose (global).
- **transpose** — swap a character or a word (or a same-line selection) with
  its left/right neighbor, UTF-8 safe (global).

---

## Table of contents

- [Features](#features)
- [Installation](#installation)
- [Quickstart](#quickstart)
- [Keymaps](#keymaps)
- [Configuration](#configuration)
- [Health](#health)
- [Architecture](#architecture)
- [Roadmap](#roadmap)

---

## Features

| Domain     | Feature                | Description                                                          |
| ---------- | ---------------------- | ------------------------------------------------------------------- |
| **lists**  | Continuation           | `<CR>`, `o`, `O` insert the next bullet (including increment).       |
| **lists**  | Empty-bullet deletion  | `<CR>` on an empty bullet ends the list.                            |
| **lists**  | Renumber               | Context-aware, respects a start offset ≠ 1.                        |
| **lists**  | Checkbox cycle         | Configurable N-state cycle (`[ ]`→`[x]`→…), dot-repeatable.          |
| **lists**  | Quick bullet toggle    | `-` on/off any line, no existing marker required, dot-repeatable.    |
| **lists**  | Quick number toggle    | `1.` on/off any line, no existing marker required, dot-repeatable.   |
| **lists**  | Quick checkbox toggle  | `- [ ]` insert→cycle→remove on any line, dot-repeatable.             |
| **lists**  | Cycle list type        | `-`→`*`→`+`→`1.`→`a)`→`I.`, dot-repeatable.                         |
| **lists**  | Form rotation          | Rotate a block/selection through forms: `1.`→`1. [ ]`→`- [ ]`→`-`.   |
| **lists**  | Sort A–Z               | Sort a block/selection alphabetically + renumber.                   |
| **lists**  | Reverse order          | Reverse a block/selection + renumber.                               |
| **lists**  | Strip checkbox         | Block/selection: strip `[ ]`/`[x]`, markers stay.                   |
| **lists**  | Indent / Dedent        | Level-aware: every indent level is cleanly renumbered.              |
| **lists**  | Move lines             | Move a line/selection up/down + reindent + renumber.               |
| **lists**  | Roman & Alpha          | `I.II.III.` and `a)b)c)` ↔ integer, cleanly encapsulated.          |
| **cycle**  | Word / boolean cycle   | Case-preserving, extensible per filetype, dot-repeatable.          |
| **cycle**  | Language packs         | `en`/`de`/`dev` on by default; `es`, `fr`, `it`, `pt`, `nl`, `ru` opt-in by name. |
| **cycle**  | Number fallback        | Native `<C-a>`/`<C-x>` for int/float/hex, via `<C-y>`/`<C-x>` or `+`/`-`. |
| **cycle**  | Date increment         | Steps the year/month/day segment of an ISO date under the cursor, with calendar-aware rollover. |
| **cycle**  | Letter cycle           | A single a-z/A-Z letter under the cursor steps through the alphabet (wraps, case preserved). |
| **cycle**  | Operator flips         | `==`↔`!=`, `&&`↔`\|\|`, `<`↔`>`, `+`↔`-`, matched by position, not `iskeyword`. |
| **cycle**  | Interactive picker     | Pick a cycle-group value via `vim.ui.select` (Telescope-backed if registered) instead of stepping. |
| **sequence** | Selection renumber  | Renumber the ordinals (`1.`, `a)`, `II.`) inside a Visual selection — numbered headlines, inline numbers mid-prose, any filetype. |
| **transpose** | Char swap           | Swap the char under the cursor with its left/right neighbor, UTF-8 safe, dot-repeatable, count = swap N times. |
| **transpose** | Word swap           | Swap the word under the cursor with its left/right neighbor word, dot-repeatable, count = swap N times. |
| **transpose** | Selection swap      | Swap a same-line visual selection with its left/right neighbor char or word, count = swap N times. |
| **lists**  | Treesitter precision   | Opt-in (`lists.precision = "treesitter"`): skip list actions inside a fenced code block, falling back safely if no parser is installed. |

Safety & performance design decisions: pure line scan by default, no
Treesitter dependency (opt-in `lists.precision = "treesitter"` for the one
case line-scanning is genuinely blind to — see below), no
`CursorMoved`/`TextChanged` autocmds (only explicit keys), `pcall` around every
buffer mutation, a single context object per action, memoized patterns,
`:checkhealth cascade`.

---

## Installation

**When to use which loading strategy:**

| Variant | Startup impact | When to use |
|---|---|---|
| `event = "VeryLazy"` | Minimal, after UI init | **Recommended** — the global word/number cycle also works in code buffers |
| `ft = { ... }` | Loads on list filetypes only | You only want cascade in Markdown/prose |
| `lazy = false` | Loads immediately | Small config, want it available instantly |

`lib.nvim` is a **required** dependency: the `:Cascade` command (built on
`lib.nvim.bindings.usercmd.composer`) fails to load without it. `lib.map`/`lib.notify`
remain soft — used when present, native fallback otherwise.

### lazy.nvim

*Recommended (global cycle also active in code):*

```lua
{
  "StefanBartl/cascade.nvim",
  dependencies = { "StefanBartl/lib.nvim" },
  event = "VeryLazy",
  opts = {
    keymaps = { preset = true },
  },
}
```

*Filetype-scoped only (lists in Markdown/prose):*

```lua
{
  "StefanBartl/cascade.nvim",
  dependencies = { "StefanBartl/lib.nvim" },
  ft = { "markdown", "markdown.mdx", "text", "tex", "norg" },
  opts = {
    keymaps = { preset = true },
  },
}
```

### packer.nvim

```lua
use({
  "StefanBartl/cascade.nvim",
  requires = { "StefanBartl/lib.nvim" },
  config = function()
    require("cascade").setup({ keymaps = { preset = true } })
  end,
})
```

### vim-plug

```vim
Plug 'StefanBartl/lib.nvim'
Plug 'StefanBartl/cascade.nvim'
```

```lua
require("cascade").setup({ keymaps = { preset = true } })
```

---

## Quickstart

### Variant A — preset (zero manual work)

```lua
require("cascade").setup({ keymaps = { preset = true } })
```

Binds `<C-y>`/`<C-x>` and `+`/`-` globally (word cycle + number fallback),
`<leader>cp` (interactive `vim.ui.select` picker for the cursor's cycle-group),
`<leader><Right>`/`<leader><Left>` (char/selection swap) and
`<leader><C-Right>`/`<leader><C-Left>` (word/selection swap) globally, and, in
the list filetypes, buffer-local `<CR>`/`<M-CR>`/`o`/`O` plus `<leader>cx` (checkbox),
`<A-->`/`<A-*>`/`<A-0>`/`<A-c>` (quick bullet/star/number/checkbox toggle —
also work on a Visual/Visual-line selection, each line toggled independently),
`<leader>ct`/`<leader>cT` (list type), `<leader>cr` (renumber). In Visual
mode, `<leader>cR` renumbers the ordinals inside the selection (global, any
filetype).

### Variant B — manual keymaps (full control)

```lua
require("cascade").setup({}) -- keymaps.preset defaults to false: no keys bound

local cascade = require("cascade")
vim.keymap.set("i", "<CR>",    cascade.cr)
vim.keymap.set("i", "<M-CR>",  cascade.cr_literal)
vim.keymap.set("n", "o",       cascade.o)
vim.keymap.set("n", "O",       cascade.O)
vim.keymap.set("n", "<C-y>",   cascade.cycle_word_next)
vim.keymap.set("n", "<C-x>",   cascade.cycle_word_prev)
vim.keymap.set("n", "+",       cascade.increment)
vim.keymap.set("n", "-",       cascade.decrement)
vim.keymap.set("n", "<Tab>",   cascade.indent)
vim.keymap.set("x", "<Tab>",   cascade.indent_visual)
vim.keymap.set("n", "<S-Tab>", cascade.dedent)
vim.keymap.set("x", "<S-Tab>", cascade.dedent_visual)
vim.keymap.set("n", "<leader><Tab>",   cascade.indent_levels)
vim.keymap.set("n", "<leader><S-Tab>", cascade.dedent_levels)
```

---

## Keymaps

Every action is exposed as a plain function on the `cascade` module, so it can
be bound with a normal `vim.keymap.set` — no `<Plug>` indirection:

| Function                    | Mode  | Action                                    |
| ---------------------------- | ----- | ----------------------------------------- |
| `cr`                          | i     | Continue list / delete empty bullet       |
| `cr_literal`                  | i     | Plain newline (skip list continuation)    |
| `o`                           | n     | Open item below                           |
| `O`                           | n     | Open item above (also below a bullet)     |
| `toggle_checkbox`             | n     | Toggle/cycle checkbox                     |
| `bullet_toggle` / `_visual`   | n / x | Toggle `-` bullet (no marker required)    |
| `star_toggle` / `_visual`     | n / x | Toggle `*` bullet (no marker required)    |
| `number_toggle` / `_visual`   | n / x | Toggle `1.` marker (no marker required)   |
| `checkbox_toggle` / `_visual` | n / x | Toggle `- [ ]` checkbox (no marker required) |
| `cycle_type_next`             | n     | List type forward                         |
| `cycle_type_prev`             | n     | List type backward                        |
| `cycle_word_next`             | n     | Word/number forward                       |
| `cycle_word_prev`             | n     | Word/number backward                      |
| `increment`                   | n     | Word/number forward (`+`; native line-down otherwise) |
| `decrement`                   | n     | Word/number backward (`-`; native line-up otherwise) |
| `cycle_pick`                  | n     | Pick a cycle-group value via `vim.ui.select` (Telescope-backed if registered) |
| `indent` / `indent_visual`    | n / x | Indent + level-aware renumber. Normal-mode count = N *lines* from cursor |
| `dedent` / `dedent_visual`    | n / x | Dedent + level-aware renumber. Normal-mode count = N *lines* from cursor |
| `indent_levels` / `dedent_levels` | n | Indent/dedent the current line by N *levels* (old count meaning of `indent`/`dedent`) |
| `move_up` / `move_up_visual`     | n / x | Move line/selection up + renumber         |
| `move_down` / `move_down_visual` | n / x | Move line/selection down + renumber       |
| `renumber`                    | n     | Renumber block                            |
| `renumber_selection`          | x     | Renumber the ordinals inside the selection (any filetype) |
| `rotate_form_next` / `_visual` | n / x | Rotate block/selection through forms      |
| `rotate_form_prev` / `_visual` | n / x | … backward                                |
| `sort` / `sort_visual`        | n / x | Sort block/selection A–Z                  |
| `reverse` / `reverse_visual`  | n / x | Reverse block/selection order             |
| `strip_checkbox` / `_visual`  | n / x | Strip checkboxes in block/selection       |
| `swap_right` / `swap_left`    | n     | Swap char with right/left neighbor (count = N times) |
| `swap_right_visual` / `swap_left_visual` | x | Swap selection with right/left neighbor char (count = N times) |
| `swap_word_right` / `swap_word_left` | n | Swap word with right/left neighbor word (count = N times) |
| `swap_word_right_visual` / `swap_word_left_visual` | x | Swap selection with right/left neighbor word (count = N times) |

> `<Tab>`/`<S-Tab>` are deliberately **not** in the preset (conflict with
> completion). Bind them yourself via `cascade.indent`/`cascade.dedent` if wanted.

### Context menu (optional)

`cascade.integrations.menu` contributes the normal-mode list actions above
(checkbox, cycle type, renumber, rotate, sort, reverse, strip) as entries in
the shape [nvzone/menu](https://github.com/nvzone/menu) expects, gated the
same way the keymaps are. cascade.nvim has no dependency on `menu` and never
opens a context menu itself — see
[docs/BINDINGS.md](docs/BINDINGS.md#context-menu-optional) for wiring it
into a host's own `<RightMouse>` dispatcher.

### User commands

Range-aware — without a range they act on the list block at the cursor, with a
range (e.g. Visual `:'<,'>`) on the selection:

One command, `:Cascade <subcommand>`, with `<Tab>` completion. Bang attaches
to the verb: `:Cascade! rotate` (not `:Cascade rotate!`).

| Command                     | Effect                                              |
| ---------------------------- | --------------------------------------------------- |
| `:Cascade rotate [next\|prev]` | Rotate form forward/backward (`!` = backward).    |
| `:Cascade sort`                | Sort block/selection A–Z (`!` = Z–A).             |
| `:Cascade reverse`             | Reverse order.                                    |
| `:Cascade strip`               | Strip checkboxes.                                 |
| `:Cascade indent [n]`          | Indent (n levels) + renumber.                     |
| `:Cascade dedent [n]`          | Dedent (n levels) + renumber.                     |
| `:Cascade renumber [all\|selection]` | Renumber block at cursor/range (`all` = whole buffer, `selection` = the ordinals inside the lines). |

In the preset, additionally buffer-local (each in Normal **and** Visual):
`<leader>cf` / `<leader>cF` (form forward/backward), `<leader>cs` (sort),
`<leader>cv` (reverse), `<leader>cX` (strip checkboxes).

**Globally** (all filetypes) the preset also binds:
- Indent/dedent: `<A-Right>` / `<A-Left>` (Normal, Visual, Insert → `<C-t>`/`<C-d>`).
- Indent/dedent one line by N levels: `<leader><A-Right>` / `<leader><A-Left>` (Normal).
- Move lines: `<A-Up>` / `<A-Down>` (Normal, Visual, Insert).
- Char/selection swap: `<leader><Right>` / `<leader><Left>` (Normal, Visual;
  count = swap N times).
- Word/selection swap: `<leader><C-Right>` / `<leader><C-Left>` (Normal,
  Visual; count = swap N times).

When moving a numbered list, it is reindented and the block is renumbered (text
moves, numbers stay sequential). Outside of lists it is a plain `:move` with an
`==` reindent.

### Level-aware indent

When indenting/dedenting a numbered list, **every indent level** is renumbered:
a deeper level starts at `1.`, returning to a shallower level continues, and the
level you left closes its gap. Outside the list filetypes it is a plain
`>>`/`<<` — so it fully replaces a generic indent mapping.

```
1. top              1. top
  1. a       →        1. a
  2. b                2. b
  3. c  (>>)            1. c     ← new sub-level starts at 1.
  4. d                3. d       ← gap closed (4→3)
  5. e                4. e       ← (5→4)
2. bot              2. bot
```

Indenting/dedenting a single line also carries its **subtree** along: any
deeper-indented lines directly following it (nested children, or its own
wrapped continuation text) shift by the same amount, instead of being left
behind.

```
1. top              1. top
  1. item    →         1. item
    1. x                 1. x
    2. y      (>>)       2. y
  2. sibling          1. sibling   ← gap closed (2→1)
```

**`vim.v.count` on `<A-Right>`/`<A-Left>` means "how many lines", not "how many
levels":** `N<A-Right>` shifts `N` consecutive lines starting at the cursor by
one level each — for a numbered outline where you want to promote/demote a
whole run of sibling lines at once. To shift a *single* line by `N` levels
instead (the old count meaning), use `N<leader><A-Right>`/`N<leader><A-Left>`.

```
1. one              1. one
2. two     2<A-Right>  1. two    ← 2 lines, one level each
3. three            2. three
```

```
1. top              1. top
  1. item    →         1. item
    1. x                 1. x
    2. y      (>>)       2. y
  2. sibling          1. sibling   ← gap closed (2→1)
```

### Form rotation

A single action rotates the **whole block** (or the Visual selection) through
the forms configured in `lists.forms`. "Numbering to checkbox" is thus the first
rotation step:

```
1. one         ->   1. [ ] one         ->   - [ ] one         ->   - one
2. two               2. [ ] two               - [ ] two               - two
```

A form combines a marker shape (`1.`, `-`, `a)`, `I.`) with an optional `[ ]`
checkbox. Existing checkbox states (`[x]`) are preserved while rotating; ordered
targets are renumbered automatically.

---

## Configuration

Defaults (excerpt — full reference in `:h cascade-config`):

```lua
require("cascade").setup({
  lists = {
    enable = true,                           -- master switch for the list domain
    features = {                             -- toggle each feature individually
      continue = true, checkbox = true, cycle_type = true,
      rotate = true, sort = true, reverse = true, strip = true,
      indent = true, move = true,
      bullet_toggle = true, number_toggle = true, checkbox_toggle = true, -- bullet_toggle also gates <A-*>
    },
    filetypes = {                            -- prose/markup filetypes (lists no-op elsewhere)
      "markdown", "markdown.mdx", "mdx", "text", "txt", "tex", "plaintex",
      "latex", "norg", "org", "rst", "asciidoc", "asciidoctor", "typst",
      "quarto", "pandoc", "vimwiki", "gitcommit", "mail",
    },
    types = { "unordered", "digit" },        -- detection order
    unordered_markers = { "-", "*", "+" },
    cycle = { "-", "*", "+", "1.", "a)", "I." },  -- cycle_type (single line)
    forms = { "1.", "1. [ ]", "- [ ]", "-" },     -- form rotation (block/visual)
    checkbox = { states = { " ", "x" } },    -- N-state cycle; multi-byte states (e.g. emoji) also work if listed here
    continue = { delete_empty = true },
    renumber = {                             -- WHEN it renumbers automatically
      enable = true,
      on = { "edit", "save" },               -- "edit" = immediately, "save" = on :w (safety net)
      blank_break = 0,                        -- blank lines that end a block (0 = any blank breaks it)
    },
  },
  cycle = {
    enable = true,
    features = { word = true, date = true, letter = true }, -- word/boolean, ISO-date, a-z/A-Z letter cycle on/off
    filetypes = nil,                         -- nil = all filetypes
    number_fallback = true,                  -- native <C-a>/<C-x> on numbers; false = skip just that
    packs = { "en", "de", "dev" },           -- built-in bundles; order = precedence. {} = only your groups
    groups = { { "==", "!=" } },             -- your own groups; checked BEFORE the packs
    per_filetype = {                         -- e.g. only in Lua:
      -- lua = { { "pairs", "ipairs" } },
    },
  },
  sequence = {                             -- renumber INSIDE a selection (global)
    enable = true,
    start = "keep",                        -- "keep" = start at the first hit; "one" = restart at 1/a/i
    types = { "digit", "ascii", "roman" }, -- order the FIRST hit is classified in; it locks the kind
  },
  transpose = {
    enable = true,
    features = { char = true, word = true }, -- char/word/selection swap on/off
  },
  keymaps = { preset = false },
  debug = false,                             -- log detect/advance/fallback decisions; see :h cascade-config
})
```

### Cycle packs (languages + dev)

`cycle.packs` switches whole bundles of word groups on by name, instead of
pasting them into `cycle.groups`. Each is one small file under
[`lua/cascade/cycle/packs/`](lua/cascade/cycle/packs) — open one to see
exactly what it contains, or as a template for your own.

| Pack | Contents |
| --- | --- |
| `en` *(default)* | `true`/`false`, `on`/`off`, `yes`/`no`, `show`/`hide`, `start`/`stop`, `up`/`down`, … |
| `de` *(default)* | `wahr`/`falsch`, `ja`/`nein`, `ein`/`aus`, `sichtbar`/`unsichtbar`, `oben`/`unten`, … |
| `dev` *(default)* | `dev`/`stage`/`prod`, `todo`/`doing`/`done`, `low`/`medium`/`high`, `draft`/`review`/`final`, `alpha`/`beta`/`rc`/`stable`, `debug`/`info`/`warn`/`error`, `get`/`post`/`put`/`patch`/`delete`, `xs`…`xl` |
| `es` `fr` `it` `pt` `nl` `ru` | The same boolean/state vocabulary in those languages. Opt-in. |

```lua
cycle = {
  packs = { "de", "en", "dev", "fr" },  -- add French, and let German win ties
  groups = { { "wahr", "vielleicht", "falsch" } }, -- your own; beats every pack
}
```

**Precedence is list order, most specific first:** `cycle.groups` →
`cycle.per_filetype[ft]` → `cycle.packs` (in the order you list them). A word
only ever belongs to the *first* group that contains it, so with
`{ "en", "es" }` the word `no` cycles to `yes`, and with `{ "es", "en" }` it
cycles to `sí`. The default `{ "en", "de", "dev" }` is collision-free;
`:checkhealth cascade` lists any collisions your own combination produces.

`packs = {}` disables all of them and leaves only your `groups`.

> **Not shipped:** Chinese, Japanese and other scripts without word
> separators. cascade finds the token under the cursor with `\k\+`, and
> `'iskeyword'`'s `@` class matches every alphabetic character — so an
> unspaced run of CJK is captured as *one* token rather than a word, and
> would never match a group entry. Cyrillic (`ru`) is fine: it uses spaces.

**Scopes — global vs. ft-scoped:** cascade has domains with deliberately
different scope:

- **`cycle`** (word/boolean + number inc/dec) is **global** — `cycle.filetypes =
  nil` means *all* filetypes. `true`↔`false`, `on`↔`off` and `<C-y>`/`<C-x>`/
  `+`/`-` work in `.txt`, `.lua`, `.md`, everywhere. Restrict it via e.g.
  `cycle.filetypes = { "lua", "markdown", "text" }`.
- **`lists`** (continue, checkbox, cycle_type, rotate, sort, reverse, strip,
  renumber) is scoped to `lists.filetypes` — sensible, since list markers are
  prose/markup specific. List actions **no-op** on lines without a marker, so a
  broad filetype list is harmless.
- **`sequence`** (renumber inside a selection) is **global**, no filetype
  option at all — it never looks at list markers, only at ordinal tokens in
  the selected text.
- **`transpose`** (char/word/selection swap) is **global**, no filetype
  option at all — swapping characters/words is filetype-agnostic by nature.
- **Indent/dedent** and **move** are effectively **global**: list-aware in the
  list filetypes (with renumber), plain `>>`/`<<` or `:move` elsewhere.

| Feature | Scope |
| --- | --- |
| Word/boolean cycle, numbers | global (every filetype) |
| Indent/dedent, move | global (renumber only in `lists.filetypes`) |
| Continue, cycle_type, rotate, sort, reverse | `lists.filetypes` |
| Checkbox, strip | `lists.filetypes` (most useful in Markdown/org/norg) |
| Quick bullet/number/checkbox toggle | `lists.filetypes` (work without an existing marker) |
| Char/word/selection swap | global (every filetype, no filetype option) |

**Renumber timing:** `lists.renumber.on` controls *when* renumbering happens —
`{ "edit" }` (immediately after indent/move/continue/…), `{ "save" }` (on `:w`
via `BufWritePre`, the whole buffer) or both. Both are on by default: "edit"
keeps in-progress edits clean, "save" is the safety net for lists it never
saw an edit event for — pasted in, typed by hand with every marker left at
"1.", or produced by another plugin. `enable = false` turns everything off —
then only `:Cascade renumber` / `<leader>cr` renumbers manually. A plain
boolean is still accepted (`true` = `{ "edit", "save" }`).

**Renumber and continuation paragraphs:** a non-marker, non-blank line (a
wrapped paragraph or note under an entry) never breaks the sequence, no matter
its own indent — it is left untouched and the numbering carries on past it,
matching Markdown's "lazy continuation": without a blank line separating it
from the item above, it belongs to that item. A **blank line**, by contrast,
ends the block: the next list starts a fresh sequence with its own start
offset — handy for keeping multiple independent numbered lists in one file.
Raise `lists.renumber.blank_break` if you want blanks tolerated inside a block:
`1` gives the CommonMark "loose list" reading (a single blank line between
items still counts as one list; two or more end it).

```markdown
1. Product Module: ...
Note on Module Export: ...        ← no blank line, sequence continues
1. Tosca Version: ...             ← renumbered to 2, not left at 1
```

**Feature toggles:** every feature can be switched off individually via
`lists.features.*`, `cycle.features.*` or `transpose.features.*`. A disabled
feature no longer runs its action and the preset does not bind its keys — keys
with a native meaning (`<CR>`, `<A-Right>`, `<C-y>`, `+`/`-`) then stay native.
`:checkhealth cascade` shows the status. Missing entries count as enabled.

**Note on `types`:** `ascii` (`a)`) and `roman` (`i.`) are opt-in because letters
are ambiguous. With a mix enabled, the order in `types` decides. Templates in
`lists.cycle`: `a/A` = alpha, `i/I` = roman.

---

## Health

```vim
:checkhealth cascade
```

Shows the Neovim version, domain status, `lib.nvim` availability (required —
gates the `:Cascade` command) and config sanity.

---

## Architecture

```
cascade.nvim/
  plugin/cascade.lua          -- load guard
  lua/cascade/
    init.lua                  -- setup() + action facade
    config/{init,DEFAULTS}    -- merge + get(path)
    core/{context,patterns}   -- 1 context/action, memoized patterns
    dispatch/init.lua         -- try-handlers → native fallback
    lists/                    -- marker, continue, renumber, checkbox,
                                 quick_toggle, cycle_type, indent, roman, alpha
    cycle/                    -- token, word_cycle
    transpose/                -- char, word (swap with left/right neighbor)
    bindings/                 -- keymaps, user commands, autocmds, which-key
    util/{lib,dotrepeat}      -- guarded lib bridge, operatorfunc repeat
    health.lua
    @types/init.lua
  docs/BINDINGS.md           -- machine-readable binding cheatsheet
  doc/cascade.txt             -- :h cascade
```

`lib.nvim` is a **required** dependency: the `:Cascade` command layer is built
on `lib.nvim.bindings.usercmd.composer`. `lib.map`/`lib.notify`/… stay soft-guarded —
used when present, native fallback otherwise.

---

## Roadmap

No open items.

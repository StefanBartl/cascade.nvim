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

`cascade.nvim` unites two feature worlds under one roof:

- **lists** — continue lists, renumber them, tick checkboxes, cycle marker
  types, indent/dedent (filetype-scoped).
- **cycle** — advance the word under the cursor (`true`→`false`, `on`→`off`, …),
  with a native `<C-y>`/`<C-x>` fallback for numbers (global).

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
| **lists**  | Cycle list type        | `-`→`*`→`+`→`1.`→`a)`→`I.`, dot-repeatable.                         |
| **lists**  | Form rotation          | Rotate a block/selection through forms: `1.`→`1. [ ]`→`- [ ]`→`-`.   |
| **lists**  | Sort A–Z               | Sort a block/selection alphabetically + renumber.                   |
| **lists**  | Reverse order          | Reverse a block/selection + renumber.                               |
| **lists**  | Strip checkbox         | Block/selection: strip `[ ]`/`[x]`, markers stay.                   |
| **lists**  | Indent / Dedent        | Level-aware: every indent level is cleanly renumbered.              |
| **lists**  | Move lines             | Move a line/selection up/down + reindent + renumber.               |
| **lists**  | Roman & Alpha          | `I.II.III.` and `a)b)c)` ↔ integer, cleanly encapsulated.          |
| **cycle**  | Word / boolean cycle   | Case-preserving, extensible per filetype, dot-repeatable.          |
| **cycle**  | Number fallback        | Native `<C-y>`/`<C-x>` for int/float/hex.                          |

Safety & performance design decisions: no Treesitter (pure line scan), no
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

`lib.nvim` is an **optional** soft dependency — if present, cascade uses
`lib.map`/`lib.notify`; otherwise it falls back to native equivalents and runs
fully standalone.

### lazy.nvim

*Recommended (global cycle also active in code):*

```lua
{
  "StefanBartl/cascade.nvim",
  dependencies = { "StefanBartl/lib.nvim" }, -- optional
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
  requires = { "StefanBartl/lib.nvim" }, -- optional
  config = function()
    require("cascade").setup({ keymaps = { preset = true } })
  end,
})
```

### vim-plug

```vim
Plug 'StefanBartl/lib.nvim'  " optional
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

Binds `<C-y>`/`<C-x>` globally (word cycle + number fallback) and, in the list
filetypes, buffer-local `<CR>`/`o`/`O` plus `<leader>cx` (checkbox),
`<leader>ct`/`<leader>cT` (list type), `<leader>cr` (renumber).

### Variant B — manual keymaps (full control)

```lua
require("cascade").setup({}) -- keymaps.preset defaults to false: no keys bound

local cascade = require("cascade")
vim.keymap.set("i", "<CR>",    cascade.cr)
vim.keymap.set("n", "o",       cascade.o)
vim.keymap.set("n", "O",       cascade.O)
vim.keymap.set("n", "<C-y>",   cascade.cycle_word_next)
vim.keymap.set("n", "<C-x>",   cascade.cycle_word_prev)
vim.keymap.set("n", "<Tab>",   cascade.indent)
vim.keymap.set("x", "<Tab>",   cascade.indent_visual)
vim.keymap.set("n", "<S-Tab>", cascade.dedent)
vim.keymap.set("x", "<S-Tab>", cascade.dedent_visual)
```

---

## Keymaps

Every action is exposed as a plain function on the `cascade` module, so it can
be bound with a normal `vim.keymap.set` — no `<Plug>` indirection:

| Function                    | Mode  | Action                                    |
| ---------------------------- | ----- | ----------------------------------------- |
| `cr`                          | i     | Continue list / delete empty bullet       |
| `o`                           | n     | Open item below                           |
| `O`                           | n     | Open item above                           |
| `toggle_checkbox`             | n     | Toggle/cycle checkbox                     |
| `cycle_type_next`             | n     | List type forward                         |
| `cycle_type_prev`             | n     | List type backward                        |
| `cycle_word_next`             | n     | Word/number forward                       |
| `cycle_word_prev`             | n     | Word/number backward                      |
| `indent` / `indent_visual`    | n / x | Indent + level-aware renumber             |
| `dedent` / `dedent_visual`    | n / x | Dedent + level-aware renumber             |
| `move_up` / `move_up_visual`     | n / x | Move line/selection up + renumber         |
| `move_down` / `move_down_visual` | n / x | Move line/selection down + renumber       |
| `renumber`                    | n     | Renumber block                            |
| `rotate_form_next` / `_visual` | n / x | Rotate block/selection through forms      |
| `rotate_form_prev` / `_visual` | n / x | … backward                                |
| `sort` / `sort_visual`        | n / x | Sort block/selection A–Z                  |
| `reverse` / `reverse_visual`  | n / x | Reverse block/selection order             |
| `strip_checkbox` / `_visual`  | n / x | Strip checkboxes in block/selection       |

> `<Tab>`/`<S-Tab>` are deliberately **not** in the preset (conflict with
> completion). Bind them yourself via `cascade.indent`/`cascade.dedent` if wanted.

### User commands

Range-aware — without a range they act on the list block at the cursor, with a
range (e.g. Visual `:'<,'>`) on the selection:

| Command                       | Effect                                              |
| ----------------------------- | --------------------------------------------------- |
| `:CascadeRotate [next\|prev]` | Rotate form forward/backward (`!` = backward).      |
| `:CascadeSort`                | Sort block/selection A–Z (`!` = Z–A).               |
| `:CascadeReverse`             | Reverse order.                                      |
| `:CascadeStrip`               | Strip checkboxes.                                   |
| `:CascadeIndent [n]`          | Indent (n levels) + renumber.                       |
| `:CascadeDedent [n]`          | Dedent (n levels) + renumber.                       |

In the preset, additionally buffer-local (each in Normal **and** Visual):
`<leader>cf` / `<leader>cF` (form forward/backward), `<leader>cs` (sort),
`<leader>cv` (reverse), `<leader>cX` (strip checkboxes).

**Globally** (all filetypes) the preset also binds:
- Indent/dedent: `<A-Right>` / `<A-Left>` (Normal, Visual, Insert → `<C-t>`/`<C-d>`).
- Move lines: `<A-Up>` / `<A-Down>` (Normal, Visual, Insert).

When moving a numbered list, it is reindented and the block is renumbered (text
moves, numbers stay sequential). Outside of lists it is a plain `:move` with an
`==` reindent.

### Level-aware indent

When indenting/dedenting a numbered list, **every indent level** is renumbered:
a deeper level starts at `1.`, returning to a shallower level continues, and the
level you left closes its gap. `vim.v.count` sets the number of levels. Outside
the list filetypes it is a plain `>>`/`<<` — so it fully replaces a generic
indent mapping.

```
1. top              1. top
  1. a       →        1. a
  2. b                2. b
  3. c  (>>)            1. c     ← new sub-level starts at 1.
  4. d                3. d       ← gap closed (4→3)
  5. e                4. e       ← (5→4)
2. bot              2. bot
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
    checkbox = { states = { " ", "x" } },    -- N-state cycle possible
    continue = { delete_empty = true },
    renumber = {                             -- WHEN it renumbers automatically
      enable = true,
      on = { "edit" },                       -- "edit" = immediately, "save" = on :w
    },
  },
  cycle = {
    enable = true,
    features = { word = true },              -- word/boolean cycle on/off
    filetypes = nil,                         -- nil = all filetypes
    number_fallback = true,
    groups = { { "true", "false" }, { "on", "off" } },
    per_filetype = {                         -- e.g. only in Lua:
      -- lua = { { "pairs", "ipairs" } },
    },
  },
  keymaps = { preset = false },
})
```

**Scopes — global vs. ft-scoped:** cascade has two domains with deliberately
different scope:

- **`cycle`** (word/boolean + number inc/dec) is **global** — `cycle.filetypes =
  nil` means *all* filetypes. `true`↔`false`, `on`↔`off` and `<C-y>`/`<C-x>`
  work in `.txt`, `.lua`, `.md`, everywhere. Restrict it via e.g.
  `cycle.filetypes = { "lua", "markdown", "text" }`.
- **`lists`** (continue, checkbox, cycle_type, rotate, sort, reverse, strip,
  renumber) is scoped to `lists.filetypes` — sensible, since list markers are
  prose/markup specific. List actions **no-op** on lines without a marker, so a
  broad filetype list is harmless.
- **Indent/dedent** and **move** are effectively **global**: list-aware in the
  list filetypes (with renumber), plain `>>`/`<<` or `:move` elsewhere.

| Feature | Scope |
| --- | --- |
| Word/boolean cycle, numbers | global (every filetype) |
| Indent/dedent, move | global (renumber only in `lists.filetypes`) |
| Continue, cycle_type, rotate, sort, reverse | `lists.filetypes` |
| Checkbox, strip | `lists.filetypes` (most useful in Markdown/org/norg) |

**Renumber timing:** `lists.renumber.on` controls *when* renumbering happens —
`{ "edit" }` (immediately after indent/move/continue/…), `{ "save" }` (on `:w`
via `BufWritePre`, the whole buffer) or both `{ "edit", "save" }`. `enable =
false` turns everything off — then only `:CascadeRenumber` / `<leader>cr`
renumbers manually. A plain boolean is still accepted (`true` = `{ "edit" }`).

**Feature toggles:** every feature can be switched off individually via
`lists.features.*` or `cycle.features.*`. A disabled feature no longer runs its
action and the preset does not bind its keys — keys with a native meaning
(`<CR>`, `<A-Right>`, `<C-y>`) then stay native. `:checkhealth cascade` shows the
status. Missing entries count as enabled.

**Note on `types`:** `ascii` (`a)`) and `roman` (`i.`) are opt-in because letters
are ambiguous. With a mix enabled, the order in `types` decides. Templates in
`lists.cycle`: `a/A` = alpha, `i/I` = roman.

---

## Health

```vim
:checkhealth cascade
```

Shows the Neovim version, domain status, `lib.nvim` integration (optional) and
config sanity.

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
                                 cycle_type, indent, roman, alpha
    cycle/                    -- token, word_cycle
    bindings/                 -- keymaps, user commands, autocmds, which-key
    util/{lib,dotrepeat}      -- guarded lib bridge, operatorfunc repeat
    health.lua
    @types/init.lua
  docs/BINDINGS.md           -- machine-readable binding cheatsheet
  doc/cascade.txt             -- :h cascade
```

`lib.nvim` is a **soft, guarded** dependency: if present, `lib.map`/`lib.notify`/…
are used, otherwise native fallbacks — the plugin runs fully standalone.

---

## Roadmap

See [docs/ROADMAP.md](docs/ROADMAP.md): subtree-aware indent, loose-list support,
date cycle, operator flips, optional Treesitter precision mode.

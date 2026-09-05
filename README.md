> **Alpha stage — active development.** This repository is in its development phase — breaking changes are to be expected at any time. Pin a commit or tag if you depend on it.

# cascade.nvim

```
                                       __
   _________ _______________ _____/ /__
  / ___/ __ `/ ___/ ___/ __ `/ __  / _ \
 / /__/ /_/ (__  ) /__/ /_/ / /_/ /  __/
 \___/\__,_/____/\___/\__,_/\__,_/\___/
        context-aware lists & cycling
```

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Neovim](https://img.shields.io/badge/Neovim-0.9%2B-57A143?logo=neovim&logoColor=white)](https://neovim.io)
[![Lua](https://img.shields.io/badge/Lua-5.1%2FLuaJIT-2C2D72?logo=lua&logoColor=white)](https://www.lua.org)
![Status](https://img.shields.io/badge/status-alpha-red)
[![CI](https://github.com/StefanBartl/cascade.nvim/actions/workflows/ci.yml/badge.svg)](https://github.com/StefanBartl/cascade.nvim/actions/workflows/ci.yml)

> 💡 Pairs well with [markdown.nvim](https://github.com/StefanBartl/markdown.nvim):
> markdown.nvim renders and structures the document (TOC, folding, tables),
> cascade edits the list content inside it (continue, renumber, rotate) — one
> reads the file, the other rewrites lines in it.
>
> 💡 And with [emojis.nvim](https://github.com/StefanBartl/emojis.nvim), which
> has a direct bridge: `require("emojis").cascade_groups()` feeds its emoji
> checkbox glyphs into `cycle.groups`, so `:Emojis toggle` (line-scoped) and
> cascade's `<C-y>` (cursor-scoped) drive one shared vocabulary.

One plugin, one pattern: **detect the context under the cursor → advance it
one step → otherwise fall back to native behavior.** That holds for Markdown
lists just as much as for `true`/`false` toggles in code.

Four domains under one roof, separated by *what has to be recognised first*:

- **lists** — continue lists, renumber them, tick checkboxes, cycle marker
  types, indent/dedent, move lines. Scoped to `lists.filetypes`.
- **cycle** — advance the token under the cursor (`true`→`false`, an ISO date,
  a lone letter, an operator) via `<C-y>`/`<C-x>` or `+`/`-`, with a native
  fallback for numbers. Global.
- **sequence** — renumber the ordinals (`1.`, `a)`, `II.`) *inside* a Visual
  selection, whatever precedes them: numbered headlines, inline numbers in
  prose. Global.
- **transpose** — swap a character or a word (or a same-line selection) with
  its neighbor, UTF-8 safe. Global.

Pure line scan by default — no Treesitter dependency, no
`CursorMoved`/`TextChanged` autocmds, `pcall` around every buffer mutation.

---

## Table of contents

- [Quickstart](#quickstart)
- [What you get with the preset](#what-you-get-with-the-preset)
- [Documentation](#documentation)
- [License](#license)

---

## Quickstart

Requires Neovim **0.9+** and [lib.nvim](https://github.com/StefanBartl/lib.nvim)
(required — the `:Cascade` command is built on it).

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

Open a Markdown file, type `1. first` and press `<CR>` — you get `2.` for
free. Press `<C-y>` on a `true` anywhere in any buffer and it becomes `false`.
That is the whole idea; everything else is more of it.

Verify your setup any time with:

```vim
:checkhealth cascade
```

Other plugin managers, and when to load on `ft` instead of `VeryLazy`:
[`docs/installation.md`](docs/installation.md).

## What you get with the preset

`keymaps.preset = true` is opt-in and binds nothing without it. Turned on, the
keys worth knowing on day one:

| Key | Where | Does |
| --- | --- | --- |
| `<CR>` / `o` / `O` | list filetypes | Continue the list, incrementing ordered markers |
| `<C-y>` / `<C-x>` | everywhere | Advance the token under the cursor, either direction |
| `+` / `-` | everywhere | The same, falling through to their native line motion |
| `<A-Right>` / `<A-Left>` | everywhere | Indent/dedent, renumbering every level it touches |
| `<A-Up>` / `<A-Down>` | everywhere | Move the line or selection, renumbering around it |
| `<leader>cf` | list filetypes | Rotate the block: `1.` → `1. [ ]` → `- [ ]` → `-` |
| `<leader>cR` | Visual | Renumber the ordinals inside the selection, any filetype |

The full set — every key, mode, and the feature switch that gates it — is the
[bindings cheatsheet](docs/BINDINGS.md). To bind actions yourself instead, see
[`docs/keymaps.md`](docs/keymaps.md).

---

## Documentation

Start at [docs/README.md](docs/README.md), which says what is where and which
question each page answers.

- [Features](docs/FEATURES/README.md) — one page per domain: cycling, lists, sequence renumbering, transposing, and what separates them.
- [Installation](docs/installation.md) — requirements, loading strategies, and every plugin manager.
- [Configuration](docs/configuration.md) — every `setup()` option and its default, plus the cycle packs and the scope rules.
- [Command reference](docs/commands.md) — `:Cascade <subcommand>`, with usage and examples.
- [Bindings cheatsheet](docs/BINDINGS.md) — every keymap, user command and autocommand at a glance.
- [Keymaps](docs/keymaps.md) — the bindable action surface, for wiring your own keys.
- [Workflow](docs/WORKFLOW.md) — which key to reach for when a line is *almost* the list item you want.
- [Architecture](docs/architecture.md) — the dispatch pattern, the four domains, and the `lib.nvim` boundary.
- [Health](docs/health.md) — what `:checkhealth cascade` reports, line by line.

There is also `:h cascade` for the same material in Vim help form.

## License

MIT — see [LICENSE](LICENSE).

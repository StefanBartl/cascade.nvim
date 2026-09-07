> **Beta stage — active development.** This repository is past its first shape and in
> active use, but the surface is not frozen: breaking changes are still possible. Pin a
> commit or tag if you depend on it.

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
![Status](https://img.shields.io/badge/status-beta-orange)
[![CI](https://github.com/StefanBartl/cascade.nvim/actions/workflows/ci.yml/badge.svg)](https://github.com/StefanBartl/cascade.nvim/actions/workflows/ci.yml)

One plugin, one pattern: **detect the context under the cursor → advance it one
step → otherwise fall back to native behavior.**

That holds for Markdown lists just as much as for `true`/`false` toggles in code,
which is why both live here instead of in two plugins that would each reimplement
the same "what am I looking at" question.

---

## Table of contents

- [Documentation](#documentation)
- [What it does](#what-it-does)
- [Around it](#around-it)
- [Requirements](#requirements)
- [Installation](#installation)
- [Quickstart](#quickstart)
- [What you get with the preset](#what-you-get-with-the-preset)
- [Integrations](#integrations)
- [Health check](#health-check)
- [Contributing](#contributing)
- [Feedback](#feedback)
- [License](#license)

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

`:help cascade` is the same reference inside the editor.

---

## What it does

Four domains under one roof, separated by *what has to be recognised first*:

| Domain | Scope | Does |
| --- | --- | --- |
| **lists** | `lists.filetypes` | Continue lists, renumber them, tick checkboxes, cycle marker types, indent/dedent, move lines |
| **cycle** | global | Advance the token under the cursor — `true`→`false`, an ISO date, a lone letter, an operator — via `<C-y>`/`<C-x>` or `+`/`-`, with a native fallback for numbers |
| **sequence** | global | Renumber the ordinals (`1.`, `a)`, `II.`) *inside* a Visual selection, whatever precedes them: numbered headlines, inline numbers in prose |
| **transpose** | global | Swap a character or a word (or a same-line selection) with its neighbor, UTF-8 safe |

The separation is not cosmetic. A list operation has to know it is in a list
before it can do anything; a cycle operation only has to know what is under the
cursor. Mixing the two produces a plugin that either refuses to work outside
Markdown or corrupts code that happens to start with a dash.

Pure line scan by default — no Treesitter dependency, no `CursorMoved` /
`TextChanged` autocmds, `pcall` around every buffer mutation.

---

## Around it

> **[markdown.nvim](https://github.com/StefanBartl/markdown.nvim)** — renders and
> structures the document (TOC, folding, tables) while cascade edits the list
> content inside it. One reads the file, the other rewrites lines in it.
>
> **[emojis.nvim](https://github.com/StefanBartl/emojis.nvim)** — has a direct
> bridge: `require("emojis").cascade_groups()` feeds its emoji checkbox glyphs
> into `cycle.groups`, so `:Emojis toggle` (line-scoped) and cascade's `<C-y>`
> (cursor-scoped) drive one shared vocabulary.
>
> Both are soft: without them everything else works unchanged.
> [lib.nvim](https://github.com/StefanBartl/lib.nvim) is the one real
> dependency — see [Requirements](#requirements).

---

## Requirements

| | |
| --- | --- |
| Neovim | **0.9+** |
| [lib.nvim](https://github.com/StefanBartl/lib.nvim) | required — the `:Cascade` command tree is built on its `usercmd.composer` |

No CLI tools, no parser, no Treesitter. Everything else is optional and detected
at runtime:

| | |
| --- | --- |
| [emojis.nvim](https://github.com/StefanBartl/emojis.nvim) | Emoji checkbox glyphs as an extra cycle group |
| [nvzone/menu](https://github.com/nvzone/menu) | A host for the context-menu entries — see [Integrations](#integrations) |

---

## Installation

```lua
-- lazy.nvim
{
  "StefanBartl/cascade.nvim",
  dependencies = { "StefanBartl/lib.nvim" },
  event = "VeryLazy",
  opts = {
    keymaps = { preset = true },
  },
}
```

`event = "VeryLazy"` because the global domains (cycle, sequence, transpose) are
not filetype-bound — loading on `ft` would leave `<C-y>` dead in every buffer
that is not Markdown. Other plugin managers, and when `ft` is the right trigger
after all, are in [docs/installation.md](docs/installation.md).

---

## Quickstart

Open a Markdown file, type `1. first` and press `<CR>` — you get `2.` for free.
Press `<C-y>` on a `true` anywhere in any buffer and it becomes `false`. That is
the whole idea; everything else is more of it.

The command tree does the same jobs without keymaps:

```vim
:Cascade rotate            " numbered list -> numbered checklist -> bullet
:Cascade renumber          " renumber the list block at the cursor
:Cascade renumber selection " renumber the ordinals inside the selected lines
:Cascade indent 2          " indent the current line two levels, renumbering
```

Verify your setup any time with:

```vim
:checkhealth cascade
```

---

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
[docs/keymaps.md](docs/keymaps.md).

---

## Integrations

### Context menu

`cascade.integrations.menu` contributes context-aware entries in the shape
[nvzone/menu](https://github.com/nvzone/menu) expects. cascade.nvim has **no**
dependency on `menu` and never opens a context menu itself; a host — typically
your own `<RightMouse>` dispatcher — composes these entries into its own menu:

```lua
local items = require("cascade.integrations.menu").items()
-- prepend or append `items` to your own menu table, then menu.open(composed)
```

The entries cover the lists domain only, and self-gate on `lists.enable`, the
buffer's filetype and each `lists.features.*` flag — exactly the gates the
buffer-local keymaps apply, so the menu never offers what the keyboard would
refuse. cycle, sequence and transpose are cursor-position-driven and do not
compress into discrete "pick an action" entries, so they are deliberately left
out. See [docs/architecture.md](docs/architecture.md).

---

## Health check

```vim
:checkhealth cascade
```

Reports whether `lib.nvim` resolved, which domains are enabled, and which
keymaps the preset actually installed. Every line it can print is in
[docs/health.md](docs/health.md).

---

## Contributing

Clone the repository and either symlink it or add it to your runtime path.
[docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) has the ground rules and the project
layout; [docs/architecture.md](docs/architecture.md) explains the dispatch
pattern a new domain has to fit into.

Pull requests very welcome.

---

## Feedback

Your feedback is very welcome. Use the
[issue tracker](https://github.com/StefanBartl/cascade.nvim/issues) to report
bugs, suggest features or ask usage questions; anything more open-ended fits a
[discussion](https://github.com/StefanBartl/cascade.nvim/discussions).

If you find this plugin useful, a ⭐ on GitHub supports its development.

---

## License

MIT — see [LICENSE](LICENSE).

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
step → otherwise fall back to native behavior.** That holds for Markdown lists
just as much as for `true`/`false` toggles in code, which is why both live
here instead of in two plugins that would each reimplement the same "what am I
looking at" question.

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

---

## Documentation

Start at [docs/README.md](docs/README.md) — what's where, and which question
each page answers.

**The Basics**

- [Installation](docs/installation.md) — requirements (Neovim 0.9+, the `lib.nvim` dependency), loading strategies, and every plugin manager.
- [Quickstart](docs/quickstart.md) — the first thing to run after installing.

**Configuration**

- [What you get with the preset](docs/what-you-get.md) — the keys worth knowing on day one, if you turn `keymaps.preset` on.
- [All options](docs/configuration.md) — every `setup()` option and its default, the cycle packs, and the scope rules.
- [Command reference](docs/commands.md) — `:Cascade <subcommand>`, with usage and examples.
- [Bindings cheatsheet](docs/BINDINGS.md) — every keymap, user command and autocommand at a glance.
- [Keymaps](docs/keymaps.md) — the bindable action surface, for wiring your own keys.

**The Rest**

- [What it does](docs/FEATURES/README.md) — one page per domain: cycling, lists, sequence renumbering, transposing, and what separates them.
- [Why it does it that way](docs/architecture.md) — the dispatch pattern, the four domains, and the `lib.nvim` boundary.
- [Workflow](docs/WORKFLOW.md) — which key to reach for when a line is *almost* the list item you want.
- [Integrations](docs/integrations.md) — the optional context-menu bridge, and why cycle/sequence/transpose are left out of it.
- [Health check](docs/health.md) — what `:checkhealth cascade` reports, line by line.
- [Contributing](docs/CONTRIBUTING.md) — ground rules and project layout.
- [Feedback](https://github.com/StefanBartl/cascade.nvim/issues) — bugs, features, usage questions; broader discussion fits the [discussions board](https://github.com/StefanBartl/cascade.nvim/discussions).

`:help cascade` is the same reference inside the editor.

---

## License

MIT — see [LICENSE](LICENSE).

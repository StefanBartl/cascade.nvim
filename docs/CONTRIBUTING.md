# Contributing to cascade.nvim

Thank you for your interest! Bugs, ideas and questions are welcome in the
[issue tracker](https://github.com/StefanBartl/cascade.nvim/issues); pull
requests very welcome.

## Getting the repository into a session

Clone it and either symlink the checkout into your plugin directory or add it to
the runtime path directly:

```lua
vim.opt.rtp:prepend("/path/to/cascade.nvim")
require("cascade").setup({ keymaps = { preset = true } })
```

## Ground rules

- Lua only, idiomatic Neovim Lua. 2-space indentation.
- **The dispatch pattern is the contract**: detect the context under the cursor,
  advance it one step, otherwise fall back to native behavior. A feature that
  cannot fall back does not belong in a keymap that shadows a native key.
- Every buffer mutation goes through `pcall`. A malformed line must leave the
  buffer as it was, not half-rewritten.
- No Treesitter, no `CursorMoved` / `TextChanged` autocmds. Line scan on demand
  is the deliberate ceiling — see [`architecture.md`](architecture.md).
- Commands are registered through `lib.nvim.bindings.usercmd.composer`, never
  with a bare `nvim_create_user_command`.
- Descriptive commit messages.

## Project layout

| Path | Contains |
| --- | --- |
| `lua/cascade/dispatch/` | The detect → advance → fall back core every domain routes through |
| `lua/cascade/lists/` | The lists domain: continue, renumber, rotate, indent, move |
| `lua/cascade/cycle/` | The cycle domain: token recognition and the value packs |
| `lua/cascade/sequence/` | Ordinal renumbering inside a Visual selection |
| `lua/cascade/transpose/` | Character, word and selection swapping |
| `lua/cascade/bindings/` | The `:Cascade` route tree and the opt-in keymap preset |
| `lua/cascade/config/` | Defaults and `setup()` validation |
| `lua/cascade/integrations/` | Soft-dependency bridges (nvzone/menu) |
| `lua/cascade/core/`, `util/` | Shared line and UTF-8 helpers |
| `docs/` | Everything the README links to |
| `TESTS/` | The spec suite, mirroring `lua/cascade/`'s paths |

## Adding a domain or a feature

1. Decide which of the four domains it belongs to. If it needs to know it is in
   a list before it can act, it is a lists feature and is gated by
   `lists.filetypes`; if it only needs the token under the cursor, it is global.
2. Implement it as a function that takes a line (or a range) and returns the
   replacement, so it is testable without a buffer.
3. Route it in `lua/cascade/bindings/` and, if it is worth a key, gate it behind
   a `features.*` flag in the preset.
4. Add a spec under `TESTS/`, including the case where the context does *not*
   match and the native fallback has to win.
5. Update [`commands.md`](commands.md), [`BINDINGS.md`](BINDINGS.md) and the
   matching page under [`FEATURES/`](FEATURES/README.md).

## Tests

`TESTS/` is **not** a plenary.nvim/busted suite — it never was. It is a
framework-free harness: every spec is a file returning `function(H) … end`,
`H` carries three assertions (`eq`, `eq_lines`, `ok`) plus two buffer helpers,
and `TESTS/run.lua` runs the specs listed in its own `specs` table. A new spec
has to be added to that list or it will not run.

Run it from the repo root:

```sh
nvim --headless -u NONE -c "set rtp+=.,../lib.nvim,../ui.nvim" -c "luafile TESTS/run.lua" -c "qa!"
```

`lib.nvim` and `ui.nvim` are expected as sibling checkouts (the `:Cascade`
composer, the keymap registry, `ui.contextmenu`, `ui.kit.select`).
[`TESTS/README.md`](../TESTS/README.md) has the full spec register, the
coverage figures, the deliberate omissions and the pinned bugs.
[GitHub Actions](../.github/workflows/ci.yml) runs the suite, `luacheck` and
`stylua --check` on every push and PR to `main`.

## Workflow

1. Fork the repository.
2. Branch as `feature/<name>`.
3. Make the change, add a spec, update the affected pages under `docs/`.
4. Open a PR with a clear description of what changed and why.

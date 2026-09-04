# Installation

Requirements, the one hard dependency, and the setup for every plugin
manager. The README carries the lazy.nvim spec only — everything else is here.

## Requirements

- **Neovim 0.9+**
- **[lib.nvim](https://github.com/StefanBartl/lib.nvim)** — a *required*
  dependency, not a soft one.

`lib.nvim` is required because the `:Cascade` command layer is built on
`lib.nvim.bindings.usercmd.composer`: without it, the command fails to load
outright. The rest of the bridge is soft — `lib.map`/`lib.notify` are used
when present and fall back to the native APIs otherwise (see
[`architecture.md`](architecture.md#the-libnvim-boundary)). `:checkhealth
cascade` tells you which of the two situations you are in before you go
looking for a bug in cascade.

Nothing else is needed. Treesitter is optional and off by default — see
`lists.precision` in [`configuration.md`](configuration.md#lists).

## Which loading strategy

The choice matters more here than for most plugins, because cascade's
`cycle`, `sequence` and `transpose` domains are **global** while `lists` is
filetype-scoped. Load it on `ft` only and the global domains do not exist
outside those filetypes — the plugin has not been loaded yet.

| Variant | Startup impact | When to use |
| --- | --- | --- |
| `event = "VeryLazy"` | Minimal, after UI init | **Recommended** — the global word/number cycle also works in code buffers |
| `ft = { … }` | Loads on list filetypes only | You only want cascade in Markdown/prose |
| `lazy = false` | Loads immediately | Small config, want it available instantly |

## lazy.nvim

*Recommended — the global cycle is active in code buffers too:*

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

*Filetype-scoped only — lists in Markdown/prose, nothing elsewhere:*

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

## packer.nvim / pckr.nvim

```lua
use({
  "StefanBartl/cascade.nvim",
  requires = { "StefanBartl/lib.nvim" },
  config = function()
    require("cascade").setup({ keymaps = { preset = true } })
  end,
})
```

## vim-plug

```vim
Plug 'StefanBartl/lib.nvim'
Plug 'StefanBartl/cascade.nvim'
```

```lua
require("cascade").setup({ keymaps = { preset = true } })
```

## `setup()` is not optional

`setup()` defines the `:Cascade` command and, with `keymaps.preset = true`,
binds the default keys. Without `preset = true` **nothing is bound at all**:
every action is still reachable, but only through a `vim.keymap.set` of your
own — see [`keymaps.md`](keymaps.md#binding-them-yourself).

## Verifying

```vim
:checkhealth cascade
```

Reports the Neovim version, whether `lib.nvim` was found, and the status of
each domain. [`health.md`](health.md) explains every line it can print.

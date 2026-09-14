# Integrations

## markdown.nvim (table rows)

`cascade.o`/`cascade.O` already continue a list bullet below/above the
cursor; when the current line isn't a list item but a
[markdown.nvim](https://github.com/StefanBartl/markdown.nvim) GFM table row,
they fall back to `markdown.core.table_mode.insert_row` instead of a bare
native open — the table analogue of the same gesture. No dependency
declaration, no config: cascade `pcall(require(...))`s the module, so the
fallback is silently unavailable when markdown.nvim isn't installed, and the
gate is otherwise identical to list continuation (`lists.enable`, the
buffer's filetype, `lists.features.continue`, and — with
`lists.precision = "treesitter"` — not inside a skip node). Header and
separator rows are left to the native key; see that function's doc comment in
markdown.nvim for the exact row it lands on.

## Context menu

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
out.

The exact entries mirrored (toggle checkbox, cycle marker type, renumber,
rotate list form, sort A-Z, reverse order, strip checkboxes) are listed
alongside the keymaps they duplicate in
[BINDINGS.md](BINDINGS.md#context-menu-optional). See
[architecture.md](architecture.md) for where `integrations/` sits in the
dispatch layout, and where the pattern would extend if a second host ever
needed its own bridge.

# Integrations

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

# What you get with the preset

`keymaps.preset = true` is opt-in and binds nothing without it — see
[configuration.md](configuration.md#keymaps). Turned on, the keys worth
knowing on day one:

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
[bindings cheatsheet](BINDINGS.md). To bind actions yourself instead, taking
the underlying functions rather than the preset, see [keymaps.md](keymaps.md).

# Keymaps — the bindable surface

Every action is a plain function on the `cascade` module, so any of them can
be bound with a normal `vim.keymap.set` — there is no `<Plug>` indirection.
This page is that surface: **which function do I bind**.

The other half of the question — **which key is already bound to what** —
is [`BINDINGS.md`](BINDINGS.md), the cheatsheet of the preset. Read that one
if you turned `keymaps.preset = true` on and want to know what you got.

## Binding them yourself

`keymaps.preset` defaults to `false`, which binds nothing at all. That is the
starting point for full control:

```lua
require("cascade").setup({}) -- no keys bound

local cascade = require("cascade")
vim.keymap.set("i", "<CR>",    cascade.cr)
vim.keymap.set("i", "<M-CR>",  cascade.cr_literal)
vim.keymap.set("n", "o",       cascade.o)
vim.keymap.set("n", "O",       cascade.O)
vim.keymap.set("n", "<C-y>",   cascade.cycle_word_next)
vim.keymap.set("n", "<C-x>",   cascade.cycle_word_prev)
vim.keymap.set("n", "<C-M-y>", cascade.cycle_char_next)
vim.keymap.set("n", "<C-M-x>", cascade.cycle_char_prev)
vim.keymap.set("n", "+",       cascade.increment)
vim.keymap.set("n", "-",       cascade.decrement)
vim.keymap.set("n", "<Tab>",   cascade.indent)
vim.keymap.set("x", "<Tab>",   cascade.indent_visual)
vim.keymap.set("n", "<S-Tab>", cascade.dedent)
vim.keymap.set("x", "<S-Tab>", cascade.dedent_visual)
vim.keymap.set("n", "<leader><Tab>",   cascade.indent_levels)
vim.keymap.set("n", "<leader><S-Tab>", cascade.dedent_levels)
```

If you only want to *move* one or two of the preset's keys rather than bind
everything by hand, do not do this — use `keymaps.globals` / `keymaps.list`
instead, which keeps the rest of the preset intact. See
[`configuration.md`](configuration.md#keymaps).

> `<Tab>`/`<S-Tab>` are deliberately **not** in the preset (they conflict with
> completion). The example above is exactly the reason the manual route
> exists.

## The actions

| Function | Mode | Action |
| --- | --- | --- |
| `cr` | i | Continue list / delete empty bullet |
| `cr_literal` | i | Plain newline (skip list continuation) |
| `o` | n | Open item below |
| `O` | n | Open item above (also below a bullet) |
| `toggle_checkbox` | n | Toggle/cycle checkbox |
| `bullet_toggle` / `_visual` | n / x | Toggle `-` bullet (no marker required) |
| `star_toggle` / `_visual` | n / x | Toggle `*` bullet (no marker required) |
| `number_toggle` / `_visual` | n / x | Toggle `1.` marker (no marker required) |
| `checkbox_toggle` / `_visual` | n / x | Toggle `- [ ]` checkbox (no marker required) |
| `cycle_type_next` | n | List type forward |
| `cycle_type_prev` | n | List type backward |
| `cycle_word_next` | n | Word/number forward |
| `cycle_word_prev` | n | Word/number backward |
| `increment` | n | Word/number forward (`+`; native line-down otherwise) |
| `decrement` | n | Word/number backward (`-`; native line-up otherwise) |
| `cycle_pick` | n | Pick a cycle-group value via `vim.ui.select` (Telescope-backed if registered) |
| `cycle_char_next` | n | Character under the cursor forward through the alphabet, inside a word too |
| `cycle_char_prev` | n | Character under the cursor backward through the alphabet |
| `indent` / `indent_visual` | n / x | Indent + level-aware renumber. Normal-mode count = N *lines* from the cursor |
| `dedent` / `dedent_visual` | n / x | Dedent + level-aware renumber. Normal-mode count = N *lines* from the cursor |
| `indent_levels` / `dedent_levels` | n | Indent/dedent the current line by N *levels* |
| `move_up` / `move_up_visual` | n / x | Move line/selection up + renumber |
| `move_down` / `move_down_visual` | n / x | Move line/selection down + renumber |
| `renumber` | n | Renumber the block at the cursor |
| `renumber_selection` | x | Renumber the ordinals inside the selection (any filetype) |
| `rotate_form_next` / `_visual` | n / x | Rotate block/selection through forms |
| `rotate_form_prev` / `_visual` | n / x | … backward |
| `sort` / `sort_visual` | n / x | Sort block/selection A–Z |
| `reverse` / `reverse_visual` | n / x | Reverse block/selection order |
| `strip_checkbox` / `_visual` | n / x | Strip checkboxes in block/selection |
| `swap_right` / `swap_left` | n | Swap char with right/left neighbor (count = N times) |
| `swap_right_visual` / `swap_left_visual` | x | Swap selection with right/left neighbor char |
| `swap_word_right` / `swap_word_left` | n | Swap word with right/left neighbor word |
| `swap_word_right_visual` / `swap_word_left_visual` | x | Swap selection with right/left neighbor word |

Three more functions exist on the module but are commands rather than
keymaps — `cycle_group_add`, `cycle_group_remove` and `cycle_groups_list`,
reachable as [`:Cascade cycle add|list|remove`](commands.md#cycle-groups-at-runtime).

## Why `cycle_char_*` is bound to two keys

The preset binds `cycle_char_next`/`cycle_char_prev` to `<C-M-y>`/`<C-M-x>`
**and** to `<leader>cy`/`<leader>cY`. They are the only actions in cascade
with a second `lhs` in their default list, and the reason is worth stating
once.

Ctrl+Alt+letter is *nearly* universal: terminals encode Alt as an `ESC`
prefix (`:help :map-alt-keys`) and `0x19` — `<C-y>` — is a byte every terminal
since the VT100 sends. "Nearly" leaves two real gaps: a terminal configured
with "Alt sends Escape" switched off, and a keyboard layout where AltGr *is*
Ctrl+Alt (German and most other European layouts) on a combination carrying a
third-level character — there no key event reaches the application at all.

Neither is detectable from inside Neovim, and a self-test cannot close the
gap: `nvim_feedkeys`/`nvim_input` inject *below* the terminal's input decoder,
so Neovim pressing its own key always succeeds, including on a terminal that
could never have sent it.

So the portable alias is bound as well, and the question stops mattering.
Drop either one the ordinary way:

```lua
keymaps = { globals = { cycle_char_next = "<C-M-y>" } }
```

## Counts

Counts are not uniform across the surface, because the useful meaning is not
the same for every action:

- **Cycle** (`cycle_word_*`, `increment`/`decrement`): `N` takes N *steps*.
  Stepping rather than jumping keeps every group kind right with one rule — a
  2-state toggle lands where its parity says (`2<C-y>` on `true` is still
  `true`), a 3-state cycle wraps, and an ISO date rolls over months. Both
  native fallbacks re-emit the count instead of swallowing it.
- **In-word char cycle** (`cycle_char_*`): `N` jumps N *places* — one edit,
  not a loop, since the replacement is always one byte wide.
- **Indent/dedent** (`indent`/`dedent`): `N` means N *lines* from the cursor,
  one level each. `indent_levels`/`dedent_levels` are the other meaning — one
  line, N levels.
- **Move** (`move_up`/`move_down`): `N` moves N lines, one step at a time, so
  reindenting and renumbering stay correct at each one. Stops at the buffer
  edge rather than erroring.
- **Quick toggles** (`bullet_toggle`, `star_toggle`): `N` widens the *scope* to
  the next N lines rather than repeating the toggle — repeating it would be a
  no-op for every even count.
- **Swaps** (`swap_*`): `N` swaps N times in a row, stopping early at the line
  boundary rather than erroring.

## Context menu (optional)

`cascade.integrations.menu` contributes the normal-mode list actions
(checkbox, cycle type, renumber, rotate, sort, reverse, strip) as entries in
the shape [nvzone/menu](https://github.com/nvzone/menu) expects, gated the
same way the keymaps are. cascade has no dependency on `menu` and never opens
a context menu itself — see
[`BINDINGS.md`](BINDINGS.md#context-menu-optional) for wiring it into a
host's own `<RightMouse>` dispatcher.

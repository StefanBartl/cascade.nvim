# cascade.nvim — Binding Cheatsheet

Machine-readable overview of every keymap, user command, and autocommand
defined by `cascade.nvim`. This file is documentation only and mirrors the
source of truth in `lua/cascade/bindings/`. Any change there must be reflected
here.

The `feature` column refers to `lists.features.*` / `cycle.features.*` /
`transpose.features.*` toggles. Disabling a feature drops its preset key and
turns its action into a no-op.

Every mapping binds directly onto a facade action (`require("cascade").<action>`)
— there is no `<Plug>` indirection. which-key (if installed) only labels the
`<leader>c` prefix as a group; it does not register the individual keys.

## Preset Keymaps

Only active when `keymaps.preset = true` is set.

### Global

Bound for every filetype.

| lhs | mode | action | feature | desc |
| --- | --- | --- | --- | --- |
| `<C-y>` | n | `cycle_word_next` | cycle.word | Increment / cycle word |
| `<C-x>` | n | `cycle_word_prev` | cycle.word | Decrement / cycle word |
| `+` | n | `increment` | cycle.word | Increment / cycle word (native line-down otherwise) |
| `-` | n | `decrement` | cycle.word | Decrement / cycle word (native line-up otherwise) |
| `<A-Right>` | n | `indent` | lists.indent | Indent (+renumber) |
| `<A-Right>` | x | `indent_visual` | lists.indent | Indent (+renumber) |
| `<A-Left>` | n | `dedent` | lists.indent | Dedent (+renumber) |
| `<A-Left>` | x | `dedent_visual` | lists.indent | Dedent (+renumber) |
| `<A-Right>` | i | `<C-t>` (native) | lists.indent | Indent line (insert) |
| `<A-Left>` | i | `<C-d>` (native) | lists.indent | Dedent line (insert) |
| `<A-Up>` | n | `move_up` | lists.move | Move line up |
| `<A-Up>` | x | `move_up_visual` | lists.move | Move selection up |
| `<A-Down>` | n | `move_down` | lists.move | Move line down |
| `<A-Down>` | x | `move_down_visual` | lists.move | Move selection down |
| `<A-Up>` | i | `<C-o>:m .-2<CR><C-o>==` (native) | lists.move | Move line up (insert) |
| `<A-Down>` | i | `<C-o>:m .+1<CR><C-o>==` (native) | lists.move | Move line down (insert) |
| `<leader><Right>` | n | `swap_right` | transpose.char | Swap char with right neighbor |
| `<leader><Left>` | n | `swap_left` | transpose.char | Swap char with left neighbor |
| `<leader><Right>` | x | `swap_right_visual` | transpose.char | Swap selection with right neighbor char |
| `<leader><Left>` | x | `swap_left_visual` | transpose.char | Swap selection with left neighbor char |

### Buffer-local

Buffer-local, bound per `lists.filetypes`.

| lhs | mode | action | feature | desc |
| --- | --- | --- | --- | --- |
| `<CR>` | i | `cr` | continue | Continue list |
| `o` | n | `o` | continue | Open item below |
| `O` | n | `O` | continue | Open item above |
| `<leader>cx` | n | `toggle_checkbox` | checkbox | Toggle checkbox |
| `<A-->` | n | `bullet_toggle` | bullet_toggle | Toggle "-" bullet (no marker required) |
| `<A-->` | x | `bullet_toggle_visual` | bullet_toggle | Toggle "-" bullet on every line in the selection |
| `<A-*>` | n | `star_toggle` | bullet_toggle | Toggle "*" bullet (no marker required) |
| `<A-*>` | x | `star_toggle_visual` | bullet_toggle | Toggle "*" bullet on every line in the selection |
| `<A-0>` | n | `number_toggle` | number_toggle | Toggle "1." marker (no marker required) |
| `<A-0>` | x | `number_toggle_visual` | number_toggle | Toggle "1." marker on every line in the selection |
| `<A-c>` | n | `checkbox_toggle` | checkbox_toggle | Toggle "- [ ]" checkbox (no marker required) |
| `<A-c>` | x | `checkbox_toggle_visual` | checkbox_toggle | Toggle "- [ ]" checkbox on every line in the selection |
| `<leader>ct` | n | `cycle_type_next` | cycle_type | Cycle list type |
| `<leader>cT` | n | `cycle_type_prev` | cycle_type | Cycle list type back |
| `<leader>cr` | n | `renumber` | — | Renumber |
| `<leader>cf` | n | `rotate_form_next` | rotate | Rotate list form |
| `<leader>cf` | x | `rotate_form_next_visual` | rotate | Rotate list form |
| `<leader>cF` | n | `rotate_form_prev` | rotate | Rotate list form back |
| `<leader>cF` | x | `rotate_form_prev_visual` | rotate | Rotate list form back |
| `<leader>cs` | n | `sort` | sort | Sort list A-Z |
| `<leader>cs` | x | `sort_visual` | sort | Sort list A-Z |
| `<leader>cv` | n | `reverse` | reverse | Reverse list order |
| `<leader>cv` | x | `reverse_visual` | reverse | Reverse list order |
| `<leader>cX` | n | `strip_checkbox` | strip | Strip checkboxes |
| `<leader>cX` | x | `strip_checkbox_visual` | strip | Strip checkboxes |

## User Commands

One command, `:Cascade <subcommand>` (built via
[`lib.nvim.usercmd.composer`](https://github.com/StefanBartl/lib.nvim), with
`<Tab>` completion), always defined regardless of the preset configuration.
**Bang now attaches to the verb, not the subcommand**: `:CascadeRotate!` is
now `:Cascade! rotate` (Vim's `!` always binds to the command name itself, so
collapsing multiple commands into one verb moves it there).

| subcommand | args | bang | range | desc |
| --- | --- | --- | --- | --- |
| `:Cascade rotate` | `[next\|prev]` | yes (`:Cascade!`) | yes | Rotate list form (range-aware; `!` or `prev` = backward) |
| `:Cascade sort` | — | yes (`:Cascade!`) | yes | Sort list A-Z (range-aware; `!` = Z-A) |
| `:Cascade reverse` | — | no | yes | Reverse list order (range-aware) |
| `:Cascade strip` | — | no | yes | Strip checkboxes (range-aware) |
| `:Cascade indent` | `[n]` | no | yes | Indent line/range (+renumber; arg = levels) |
| `:Cascade dedent` | `[n]` | no | yes | Dedent line/range (+renumber; arg = levels) |
| `:Cascade renumber` | `[all]` | no | yes | Renumber list block (range-aware; `all` = every list in the buffer) |

## Autocommands

Registered by `setup()`.

| event | group | pattern | when | desc |
| --- | --- | --- | --- | --- |
| `FileType` | `cascade_list_keymaps` | `lists.filetypes` | `keymaps.preset = true` | Bind buffer-local list keymaps |
| `BufWritePre` | `cascade_renumber_save` | `*` | `"save" in lists.renumber.on` | Renumber ordered lists on save |

# cascade.nvim — Binding Cheatsheet

Machine-readable overview of every keymap, user command, and autocommand
defined by `cascade.nvim`. This file is documentation only and mirrors the
source of truth in `lua/cascade/bindings/`. Any change there must be reflected
here.

The `feature` column refers to `lists.features.*` / `cycle.features.*`
toggles. Disabling a feature drops its preset key and turns its action into a
no-op.

## Plug Mappings

The stable `<Plug>` surface is always defined, regardless of the preset configuration.

| lhs | mode | action | desc |
| --- | --- | --- | --- |
| `<Plug>(cascade-cr)` | i | cr | Continue list / delete empty bullet |
| `<Plug>(cascade-o)` | n | o | Open item below |
| `<Plug>(cascade-O)` | n | O | Open item above |
| `<Plug>(cascade-checkbox)` | n | toggle_checkbox | Toggle/cycle checkbox |
| `<Plug>(cascade-cycle-type-next)` | n | cycle_type_next | List marker type forward |
| `<Plug>(cascade-cycle-type-prev)` | n | cycle_type_prev | List marker type backward |
| `<Plug>(cascade-cycle-word-next)` | n | cycle_word_next | Word/number forward (native `<C-y>` fallback) |
| `<Plug>(cascade-cycle-word-prev)` | n | cycle_word_prev | Word/number backward (native `<C-x>` fallback) |
| `<Plug>(cascade-indent)` | n, x | indent | Indent + level-aware renumber |
| `<Plug>(cascade-dedent)` | n, x | dedent | Dedent + level-aware renumber |
| `<Plug>(cascade-renumber)` | n | renumber | Renumber the block at the cursor |
| `<Plug>(cascade-rotate-form)` | n, x | rotate_form_next | Rotate block/selection through forms |
| `<Plug>(cascade-rotate-form-back)` | n, x | rotate_form_prev | Rotate forms backward |
| `<Plug>(cascade-sort)` | n, x | sort | Sort block/selection A-Z |
| `<Plug>(cascade-reverse)` | n, x | reverse | Reverse block/selection order |
| `<Plug>(cascade-strip-checkbox)` | n, x | strip_checkbox | Strip checkboxes (markers stay) |
| `<Plug>(cascade-move-up)` | n, x | move_up | Move line/selection up + renumber |
| `<Plug>(cascade-move-down)` | n, x | move_down | Move line/selection down + renumber |

## Preset Keymaps

Only active when `keymaps.preset = true` is set.

### Global

Bound for every filetype.

| lhs | mode | rhs | feature | desc |
| --- | --- | --- | --- | --- |
| `<C-y>` | n | `<Plug>(cascade-cycle-word-next)` | cycle.word | Increment / cycle word |
| `<C-x>` | n | `<Plug>(cascade-cycle-word-prev)` | cycle.word | Decrement / cycle word |
| `<A-Right>` | n, x | `<Plug>(cascade-indent)` | lists.indent | Indent (+renumber) |
| `<A-Left>` | n, x | `<Plug>(cascade-dedent)` | lists.indent | Dedent (+renumber) |
| `<A-Right>` | i | `<C-t>` | lists.indent | Indent line (insert) |
| `<A-Left>` | i | `<C-d>` | lists.indent | Dedent line (insert) |
| `<A-Up>` | n, x | `<Plug>(cascade-move-up)` | lists.move | Move line/selection up |
| `<A-Down>` | n, x | `<Plug>(cascade-move-down)` | lists.move | Move line/selection down |
| `<A-Up>` | i | `<C-o>:m .-2<CR><C-o>==` | lists.move | Move line up (insert) |
| `<A-Down>` | i | `<C-o>:m .+1<CR><C-o>==` | lists.move | Move line down (insert) |

### Buffer-local

Buffer-local, bound per `lists.filetypes`.

| lhs | mode | rhs | feature | desc |
| --- | --- | --- | --- | --- |
| `<CR>` | i | `<Plug>(cascade-cr)` | continue | Continue list |
| `o` | n | `<Plug>(cascade-o)` | continue | Open item below |
| `O` | n | `<Plug>(cascade-O)` | continue | Open item above |
| `<leader>cx` | n | `<Plug>(cascade-checkbox)` | checkbox | Toggle checkbox |
| `<leader>ct` | n | `<Plug>(cascade-cycle-type-next)` | cycle_type | Cycle list type |
| `<leader>cT` | n | `<Plug>(cascade-cycle-type-prev)` | cycle_type | Cycle list type back |
| `<leader>cr` | n | `<Plug>(cascade-renumber)` | — | Renumber |
| `<leader>cf` | n, x | `<Plug>(cascade-rotate-form)` | rotate | Rotate list form |
| `<leader>cF` | n, x | `<Plug>(cascade-rotate-form-back)` | rotate | Rotate list form back |
| `<leader>cs` | n, x | `<Plug>(cascade-sort)` | sort | Sort list A-Z |
| `<leader>cv` | n, x | `<Plug>(cascade-reverse)` | reverse | Reverse list order |
| `<leader>cX` | n, x | `<Plug>(cascade-strip-checkbox)` | strip | Strip checkboxes |

## User Commands

Always defined, regardless of the preset configuration.

| name | args | bang | range | desc |
| --- | --- | --- | --- | --- |
| `:CascadeRotate` | `[next\|prev]` | yes | yes | Rotate list form (range-aware; `!` = backward) |
| `:CascadeSort` | — | yes | yes | Sort list A-Z (range-aware; `!` = Z-A) |
| `:CascadeReverse` | — | no | yes | Reverse list order (range-aware) |
| `:CascadeStrip` | — | no | yes | Strip checkboxes (range-aware) |
| `:CascadeIndent` | `[n]` | no | yes | Indent line/range (+renumber; arg = levels) |
| `:CascadeDedent` | `[n]` | no | yes | Dedent line/range (+renumber; arg = levels) |

## Autocommands

Registered by `setup()`.

| event | group | pattern | when | desc |
| --- | --- | --- | --- | --- |
| `FileType` | `cascade_list_keymaps` | `lists.filetypes` | `keymaps.preset = true` | Bind buffer-local list keymaps |
| `BufWritePre` | `cascade_renumber_save` | `*` | `"save" in lists.renumber.on` | Renumber ordered lists on save |

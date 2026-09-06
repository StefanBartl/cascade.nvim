# cascade.nvim — Binding Cheatsheet

Every keymap, user command, and autocommand `cascade.nvim` defines. Kept in
sync with `lua/cascade/bindings/`.

The `feature` column refers to `lists.features.*` / `cycle.features.*` /
`transpose.features.*` toggles (the sequence domain has a single
`sequence.enable` switch instead). Disabling a feature drops its preset key and
turns its action into a no-op.

Every mapping binds directly onto a facade action (`require("cascade").<action>`)
— there is no `<Plug>` indirection. which-key (if installed) only labels the
`<leader>c` prefix as a group; it does not register the individual keys.

To bind those actions to keys of your own instead of taking the preset, the
list of them is [`keymaps.md`](keymaps.md); to move or drop a single preset
key, [`configuration.md`](configuration.md#keymaps).

## Preset Keymaps

Only active when `keymaps.preset = true` is set.

### Global

Bound for every filetype.

| lhs | mode | action | feature | desc |
| --- | --- | --- | --- | --- |
| `<C-y>` | n | `cycle_word_next` | cycle.word | Increment / cycle word. `N` = N steps |
| `<C-x>` | n | `cycle_word_prev` | cycle.word | Decrement / cycle word. `N` = N steps |
| `+` | n | `increment` | cycle.word | Increment / cycle word (native line-down otherwise) |
| `-` | n | `decrement` | cycle.word | Decrement / cycle word (native line-up otherwise). `N` = N steps |
| `<leader>cp` | n | `cycle_pick` | cycle.word | Pick a cycle-group value via `vim.ui.select` |
| `<C-M-y>` | n | `cycle_char_next` | cycle.char | Step the char under the cursor through the alphabet, inside a word too. `N` = N places |
| `<leader>cy` | n | `cycle_char_next` | cycle.char | The same action, on a key no terminal can fail to send (see below) |
| `<C-M-x>` | n | `cycle_char_prev` | cycle.char | … backward. `N` = N places |
| `<leader>cY` | n | `cycle_char_prev` | cycle.char | … backward, portable alias |
| `<leader>cR` | x | `renumber_selection` | sequence.enable | Renumber the ordinal tokens inside the selection (any filetype) |
| `<A-Right>` | n | `indent` | lists.indent | Indent (+renumber). No count/1: current line. `N` = N lines from cursor, 1 level each |
| `<A-Right>` | x | `indent_visual` | lists.indent | Indent (+renumber) |
| `<A-Left>` | n | `dedent` | lists.indent | Dedent (+renumber). No count/1: current line. `N` = N lines from cursor, 1 level each |
| `<A-Left>` | x | `dedent_visual` | lists.indent | Dedent (+renumber) |
| `<A-Right>` | i | `<C-t>` (native) | lists.indent | Indent line (insert) |
| `<A-Left>` | i | `<C-d>` (native) | lists.indent | Dedent line (insert) |
| `<leader><A-Right>` | n | `indent_levels` | lists.indent | Indent current line by `N` levels (old count meaning of `<A-Right>`) |
| `<leader><A-Left>` | n | `dedent_levels` | lists.indent | Dedent current line by `N` levels (old count meaning of `<A-Left>`) |
| `<A-Up>` | n | `move_up` | lists.move | Move line up. `N` = N lines |
| `<A-Up>` | x | `move_up_visual` | lists.move | Move selection up |
| `<A-Down>` | n | `move_down` | lists.move | Move line down. `N` = N lines |
| `<A-Down>` | x | `move_down_visual` | lists.move | Move selection down |
| `<A-Up>` | i | `<C-o>:m .-2<CR><C-o>==` (native) | lists.move | Move line up (insert) |
| `<A-Down>` | i | `<C-o>:m .+1<CR><C-o>==` (native) | lists.move | Move line down (insert) |
| `<leader><Right>` | n | `swap_right` | transpose.char | Swap char with right neighbor. `N` = swap N times |
| `<leader><Left>` | n | `swap_left` | transpose.char | Swap char with left neighbor. `N` = swap N times |
| `<leader><Right>` | x | `swap_right_visual` | transpose.char | Swap selection with right neighbor char. `N` = swap N times |
| `<leader><Left>` | x | `swap_left_visual` | transpose.char | Swap selection with left neighbor char. `N` = swap N times |
| `<leader><C-Right>` | n | `swap_word_right` | transpose.word | Swap word with right neighbor word. `N` = swap N times |
| `<leader><C-Left>` | n | `swap_word_left` | transpose.word | Swap word with left neighbor word. `N` = swap N times |
| `<leader><C-Right>` | x | `swap_word_right_visual` | transpose.word | Swap selection with right neighbor word. `N` = swap N times |
| `<leader><C-Left>` | x | `swap_word_left_visual` | transpose.word | Swap selection with left neighbor word. `N` = swap N times |

### Count support

Indent/dedent had a deliberate count design from the start; the cycle, move
and quick-toggle keys did not. They do now, and the meaning differs per key
because the useful one does:

- **In-word char cycle** (`<C-M-y>`/`<C-M-x>`): `N` jumps N places (`3<C-M-y>`
  on `a` gives `d`) — one edit, not a loop, since the replacement is always
  one byte wide. No native fallback: off an a-z/A-Z byte these keys are a
  silent no-op, because unlike `<C-y>`/`+` they have no meaning of their own
  to hand the keypress back to.
- **Cycle** (`<C-y>`/`<C-x>`/`+`/`-`): `N` takes N steps. Stepping rather
  than jumping keeps every group kind right with one rule — a 2-state
  toggle lands where its parity says (`2<C-y>` on `true` is still `true`),
  a 3-state cycle wraps, and an ISO date rolls over months (`3<C-y>` on
  `2026-08-30` gives `2026-09-02`, not day 33).
  The two native fallbacks re-emit the count instead of swallowing it, so
  `3<C-y>` on a number is `<C-a>` three times and on nothing cyclable it is
  a three-line scroll.
- **Move** (`<A-Up>`/`<A-Down>`): `N` moves N lines, one step at a time so
  reindenting and list renumbering stay correct at each one. Stops at the
  buffer edge rather than erroring.
- **Quick-toggle** (`<A-->`/`<A-*>`): `N` widens the *scope* to the next N
  lines rather than repeating the toggle — repeating it would be a no-op for
  every even count. Same reinterpretation `<leader>et` uses in emojis.nvim.

### Why `cycle_char_*` is bound to two keys

`cycle_char_next`/`cycle_char_prev` are the only actions here with a second
`lhs` in their `default` list. Ctrl+Alt+letter is *nearly* universal —
terminals send it as `ESC` plus the letter's control byte (`:help
:map-alt-keys`), and `0x19` (`<C-y>`) is a byte every terminal since the VT100
emits. "Nearly" leaves two real gaps: a terminal configured with "Alt sends
Escape" off, and a keyboard layout where AltGr *is* Ctrl+Alt (German, and most
other European layouts) and the combination carries a third-level character —
there the key never reaches the application at all.

Neither is detectable from inside Neovim. Nvim does query the terminal for
"CSI u" support at startup (`:help tui-csiu`), but never exposes the answer to
Lua, and that answer would be the wrong question anyway: it describes the
terminal, not the path through tmux/ssh/the keyboard layout that a specific
key actually takes. A self-test is impossible for a more basic reason —
`nvim_feedkeys`/`nvim_input` inject *below* the terminal's decoder, so
pressing your own key always succeeds, including on a terminal that could
never have sent it.

So the portable alias is simply bound as well. One extra key, and the question
stops mattering.

### Buffer-local

Buffer-local, bound per `lists.filetypes`.

| lhs | mode | action | feature | desc |
| --- | --- | --- | --- | --- |
| `<CR>` | i | `cr` | continue | Continue list |
| `<M-CR>` | i | `cr_literal` | continue | Plain newline (skip list continuation) |
| `o` | n | `o` | continue | Open item below |
| `O` | n | `O` | continue | Open item above (also from a non-list line directly below a bullet) |
| `<leader>cx` | n | `toggle_checkbox` | checkbox | Toggle checkbox |
| `<A-->` | n | `bullet_toggle` | bullet_toggle | Toggle "-" bullet (no marker required). `N` = the next N lines |
| `<A-->` | x | `bullet_toggle_visual` | bullet_toggle | Toggle "-" bullet on every line in the selection |
| `<A-*>` | n | `star_toggle` | bullet_toggle | Toggle "*" bullet (no marker required). `N` = the next N lines |
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

## Context Menu (optional)

`cascade.integrations.menu` contributes the normal-mode subset of the
buffer-local keymaps above (Toggle checkbox, Cycle list marker type,
Renumber, Rotate list form, Sort A-Z, Reverse order, Strip checkboxes) as
entries in the shape [nvzone/menu](https://github.com/nvzone/menu) expects.
Same gating as the keymaps: `lists.enable`, the buffer's filetype being in
`lists.filetypes`, and each `lists.features.*` flag.

cascade.nvim has **no** dependency on `menu` and never opens a context menu
itself — a host (typically your own `<RightMouse>` dispatcher) has to
compose these entries into its own menu for them to ever be shown:

```lua
local items = require("cascade.integrations.menu").items()  -- current buffer
local sub = require("cascade.integrations.menu").submenu()  -- { name = "  Cascade", items = {…} } | nil
```

## User Commands

One command, `:Cascade <subcommand>` (built via
[`lib.nvim.bindings.usercmd.composer`](https://github.com/StefanBartl/lib.nvim), with
`<Tab>` completion), always defined regardless of the preset configuration.
**The bang attaches to the verb, not the subcommand**: `:Cascade! rotate`, not
`:Cascade rotate!` — Vim's `!` always binds to the command name itself, so
collapsing multiple commands into one verb moves it there.

Full usage and examples: [`commands.md`](commands.md).

| subcommand | args | bang | range | desc |
| --- | --- | --- | --- | --- |
| `:Cascade cycle list` | — | no | no | List the cycle groups in effect for this buffer (globals + this filetype's) |
| `:Cascade cycle add` | `{values}` | no | no | Add a cycle group for this session: `:Cascade cycle add on,off,maybe` |
| `:Cascade cycle remove` | `{value}` | no | no | Remove the runtime cycle group containing a value |
| `:Cascade rotate` | `[next\|prev]` | yes (`:Cascade!`) | yes | Rotate list form (range-aware; `!` or `prev` = backward) |
| `:Cascade sort` | — | yes (`:Cascade!`) | yes | Sort list A-Z (range-aware; `!` = Z-A) |
| `:Cascade reverse` | — | no | yes | Reverse list order (range-aware) |
| `:Cascade strip` | — | no | yes | Strip checkboxes (range-aware) |
| `:Cascade indent` | `[n]` | no | yes | Indent line/range (+renumber; arg = levels) |
| `:Cascade dedent` | `[n]` | no | yes | Dedent line/range (+renumber; arg = levels) |
| `:Cascade renumber` | `[all\|selection]` | no | yes | Renumber list block (range-aware; `all` = every list in the buffer, `selection` = the ordinal tokens inside the lines) |

## Autocommands

Registered by `setup()`.

| event | group | pattern | when | desc |
| --- | --- | --- | --- | --- |
| `FileType` | `cascade_list_keymaps` | `lists.filetypes` | `keymaps.preset = true` | Bind buffer-local list keymaps |
| `FileType` | `cascade_list_format` | `lists.filetypes` | `lists.continue.hanging_indent` | Set `formatlistpat`/`formatoptions` for `gq` hanging indent |
| `BufWritePre` | `cascade_renumber_save` | `*` | `"save" in lists.renumber.on` | Renumber ordered lists on save (`pcall`-wrapped, so a renumbering bug can't block the write) |

Both `FileType` autocmds also apply immediately, once, to whatever buffer is
already open with a matching filetype at `setup()` time — not just buffers
opened afterward.

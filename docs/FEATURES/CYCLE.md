# Cycle

Advances the token under the cursor one step: a word/boolean, an ISO date
segment, a numeric value (native fallback), or an operator, in either
direction. Global by default (`cycle.filetypes = nil` means every
filetype) — `true`↔`false` and `<C-y>`/`<C-x>`/`+`/`-` work in `.lua`,
`.md`, `.txt`, everywhere. Restrict scope via `cycle.filetypes`. Each
feature can be switched off individually via `cycle.features.*`.

## Word / boolean cycle

Steps the word under the cursor through a configured group
(`true`↔`false`, `on`↔`off`, `enabled`↔`disabled`, …). Case-preserving
(matches the replacement's case shape to the original), extensible per
filetype via `cycle.per_filetype`, dot-repeatable.

The vocabulary comes from two places: `cycle.groups` (yours, plus the
operator flips below) and the **packs** — named bundles switched on by name,
`{ "en", "de", "dev" }` by default. A word only ever belongs to the first
group that holds it, so the order of `cycle.packs` is a precedence order and
not a set. Both the pack contents and that rule are in
[`../configuration.md#cycle-packs`](../configuration.md#cycle-packs);
`:checkhealth cascade` names every word a combination of packs makes
unreachable.

- **Module:** `cycle/word_cycle.lua` (`M.cycle`), `cycle/packs/` (`M.resolve`, `M.conflicts`), `cycle/token.lua` (`M.case_shape`, `M.apply_shape`)
- **Config:** `cycle.features.word`, `cycle.groups`, `cycle.packs`, `cycle.per_filetype`

## Runtime cycle groups

`cycle.groups` was config-only, so trying out a group meant editing the
config and reloading — enough friction that for a group you need for the next
ten minutes, you simply wouldn't.

```vim
:Cascade cycle add alpha,beta,gamma
:Cascade cycle add TODO, IN PROGRESS ,DONE
:Cascade cycle list
:Cascade cycle remove beta
```

`add` appends to the live table that `word_cycle.groups_for` reads on every
keypress, so it takes effect immediately. Values may contain spaces — the
whole tail is taken, not just the first token, since otherwise
`TODO,IN PROGRESS,DONE` would silently lose everything after the space.

Values are trimmed, and duplicates inside one group are dropped — a repeated
value would stall the cycle on itself. If fewer than two distinct values
remain, the group is refused: a cycle of one cannot cycle.

`remove` drops the first group containing the value you name, so any member
identifies it. `list` reports the global groups *and* the current filetype's,
since those are separate config keys and reading either alone answers the
wrong question.

**Deliberately not persisted.** It lasts for the session; the config file
stays the single source of truth for groups worth keeping. A group added in
passing and then forgotten should not quietly outlive the reason it was
added.

- **Module:** `init.lua` (`cycle_group_add`, `cycle_group_remove`,
  `cycle_groups_list`)
- **Usercmds:** `:Cascade cycle add|list|remove`
- **Tests:** `TESTS/commands_spec.lua`
- **Keymaps:** `<C-y>`/`<C-x>` (global, preset), `+`/`-` when nothing else matches (see below)

## Number fallback

When the cursor is on a plain numeric token (int/float/hex) and no word
cycle group or date matches, `<C-y>`/`<C-x>`/`+`/`-` fall back to native
`<C-a>`/`<C-x>` instead of doing nothing.

- **Module:** `init.lua` (`cycle_word_work`), `cycle/token.lua` (`M.is_numeric`)
- **Count:** `N` takes N steps. The number fallback re-emits the
  count (`3<C-y>` on a number is `<C-a>` three times), as does the native-key
  fallback — dropping it would make the count silently mean 1 exactly where
  the user can see it should not. The count is captured before the dot-repeat
  trampoline, the same way `pending_swap_count` is, because the trampoline
  does not carry `vim.v.count1` through to the deferred work.
- **Config:** `cycle.number_fallback`

## Date increment

Steps the year/month/day segment of an ISO date (`YYYY-MM-DD`) under the
cursor, with calendar-aware rollover (respects days-per-month, leap
years). Checked before the word-cycle group match.

- **Module:** `cycle/date.lua` (`M.span`, `M.step`)
- **Config:** `cycle.features.date`

## In-word char cycle

`<C-M-y>`/`<C-M-x>` — equivalently `<leader>cy`/`<leader>cY`, both are bound —
step the single character under the cursor through the alphabet, wrapping,
case preserved, **wherever it sits**, including in the middle of a word.

This exists because `<C-y>` deliberately cannot do it. `<C-y>` reads the whole
keyword under the cursor (`'iskeyword'`, via `token.span`) and looks it up in
the cycle groups; on a word that is in no group it hands the keypress back to
its native meaning. So `a` on its own cycles (the letter feature sees a
one-character token), but the `a` inside `cat` never does — the token is
`cat`, no group holds it, and nothing happens. Widening that chain to "no
group matched, so step the character instead" would rewrite text on every
unknown word, exactly where the user expects a no-op. A separate key says
which of the two was meant, and keeps `<C-y>` predictable.

```
cat   <C-M-y>  (cursor on "a")  ->  cbt
caT   <C-M-y>  (cursor on "T")  ->  caU     (case preserved)
czt   <C-M-y>  (cursor on "z")  ->  cat     (wraps)
a     3<C-M-y>                  ->  d       (count = N places, one edit)
```

Off an a-z/A-Z byte (a digit, punctuation, past the end of the line, a
multi-byte character) it is a silent no-op — unlike `<C-y>`/`+`, these keys
have no native meaning to fall back to. Dot-repeatable like every other cycle
action.

### Two keys for one action

This is the only action in cascade with a second `lhs` in its `default` list,
and the reason is worth writing down once.

Ctrl+Alt+letter is *nearly* universal: terminals encode Alt as an `ESC` prefix
(`:help :map-alt-keys`) and `0x19` — `<C-y>` — is a byte every terminal since
the VT100 sends, so `ESC 0x19` arrives and Neovim reassembles it into
`<M-C-y>`. Two real gaps remain: a terminal with "Alt sends Escape" switched
off, and a keyboard layout where AltGr *is* Ctrl+Alt (German and most European
layouts) on a combination that carries a third-level character — `AltGr+q`
produces `@`, and no key event ever reaches the application.

**Neither is detectable, and cascade deliberately does not try.** Neovim asks
the terminal at startup whether it speaks "CSI u" (`:help tui-csiu`) but
exposes the answer to no Lua API; and even with it, "this terminal supports
the protocol" is not "this key survives the trip through tmux, ssh and the
keyboard layout". A self-test cannot close the gap either:
`nvim_feedkeys`/`nvim_input` inject *below* the terminal's input decoder, so
Neovim pressing its own key always succeeds — including on a terminal that
could never have sent it. There is no way to make a terminal send a key to
itself.

So both keys are bound, and the question stops mattering. Drop either one the
ordinary way: `keymaps = { globals = { cycle_char_next = "<C-M-y>" } }`.

- **Module:** `cycle/letter.lua` (`M.step_at`), `init.lua` (`cycle_char_work`)
- **Config:** `cycle.features.char`
- **Tests:** `TESTS/cycle_spec.lua`, `TESTS/commands_spec.lua` (both keys bound)
- **Keymaps:** `<C-M-y>`/`<C-M-x>` and `<leader>cy`/`<leader>cY` (global, preset)

## Operator flips

Flips an operator in place — `==`↔`!=`, `&&`↔`||`, `<`↔`>`, `+`↔`-` —
matched by literal cursor position rather than `iskeyword`, since these
aren't keyword characters the normal word-span scan would catch.

- **Module:** `cycle/token.lua` (`M.operator_span`)
- **Config:** part of `cycle.groups` (the operator-pair entries)

## Interactive picker

Opens `vim.ui.select` (Telescope-backed if a picker is registered) over
every value in the cursor's cycle group — word or operator — replacing it
with whichever is chosen, instead of stepping one at a time. Silent no-op
when the cursor isn't on a cyclable token.

- **Module:** `cycle/word_cycle.lua` (`M.pick`)
- **Config:** `cycle.features.word` (shares the gate with word cycle)
- **Keymaps:** `<leader>cp` (global, preset)

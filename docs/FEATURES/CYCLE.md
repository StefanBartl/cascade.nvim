# Cycle

Advances the token under the cursor one step: a word/boolean, an ISO date
segment, a numeric value (native fallback), or an operator, in either
direction. Global by default (`cycle.filetypes = nil` means every
filetype) — `true`↔`false` and `<C-y>`/`<C-x>`/`+`/`-` work in `.lua`,
`.md`, `.txt`, everywhere. Restrict scope via `cycle.filetypes`. Each
feature can be switched off individually via `cycle.features.*`.

## Word / boolean cycle

Steps the word under the cursor through a configured group
(`true`↔`false`, `on`↔`off`, `enabled`↔`disabled`, …, 22 built-in 2-state
pairs plus a 3-state `. / \` cycle). Case-preserving (matches the
replacement's case shape to the original), extensible per filetype via
`cycle.per_filetype`, dot-repeatable.

- **Module:** `cycle/word_cycle.lua` (`M.cycle`), `cycle/token.lua` (`M.case_shape`, `M.apply_shape`)
- **Config:** `cycle.features.word`, `cycle.groups`, `cycle.per_filetype`

## Runtime cycle groups (2026-08-24)

`cycle.groups` was config-only, so trying out a group meant editing the
config and reloading — enough friction that for a group you need for the next
ten minutes, you simply wouldn't. Closes the flag/option audit's entry.

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

Two refusals, both because the result would be a cycle that cannot cycle: a
group with fewer than two distinct values, and one with duplicates (which
would stall on the repeat).

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
- **Count (2026-08-24):** `N` takes N steps. The number fallback re-emits the
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

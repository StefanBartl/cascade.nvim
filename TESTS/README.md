# Tests

Headless spec suite for cascade.nvim. Pure line-scanning logic (marker parsing,
roman/alpha, renumber, transforms) is trivially testable without a UI; the
wiring, the command layer and `:checkhealth` are driven against real buffers
and real Ex commands.

## Run

From the repo root:

```sh
nvim --headless -u NONE -c "set rtp+=.,../lib.nvim,../ui.nvim" -c "luafile TESTS/run.lua" -c "qa!"
```

or via the backwards-compatible entry point:

```sh
nvim --headless -u NONE -c "set rtp+=.,../lib.nvim,../ui.nvim" -c "luafile scripts/smoke.lua" -c "qa!"
```

The runner prints one line per spec and exits non-zero if any spec failed
(`CASCADE_TESTS_OK` / `CASCADE_SMOKE_OK` on success).

`lib.nvim` and `ui.nvim` are sibling checkouts on the runtimepath, exactly as
`.github/workflows/ci.yml` arranges them. Both are real dependencies here, not
stubs: `lib.nvim` provides the `:Cascade` composer, the keymap registry and the
`lib.lua.*` numeral/case/config helpers, and `ui.nvim` provides
`ui.contextmenu` (the right-click integration) and `ui.kit.select` (the cycle
picker). Dropping `../lib.nvim` from the path makes most of the suite fail, not
skip.

## Layout

| File                          | Covers                                                                    |
| ----------------------------- | -------------------------------------------------------------------------- |
| `harness.lua`                 | Shared assertions (`eq`, `eq_lines`, `ok`) and `scratch(ft)`/`editable(ft)` buffer helpers. |
| `run.lua`                     | Runner: loads every spec in the list, reports results, sets the exit code. |
| `units_spec.lua`              | Pure functions: roman, alpha, marker parse/advance/render.               |
| `lib_fallbacks_spec.lua`      | `cascade.util.lib`'s *standalone* fallbacks (case shape/apply, roman, alpha), each asserted both through lib.nvim and with the specific `lib.lua.*` module made absent. |
| `packs_spec.lua`              | The nine shipped cycle packs as data (group shape, no duplicates), `resolve`'s cache and its warn-once behaviour, `conflicts` over the full set. |
| `shape_cycle_type_spec.lua`   | `lists/shape.lua`'s template decoding and `lists/cycle_type.lua`'s per-item marker rotation, including the `types`-order ambiguity between `ascii` and `roman`. |
| `dispatch_move_spec.lua`      | `cascade.dispatch`'s handler chain and native fallback, `lists/move.lua`'s range move, `lists/checkbox.lua`'s unknown-state branch. |
| `lists_spec.lua`              | Checkbox, quick_toggle, renumber (run/tree/all), transforms, indent, move. |
| `cycle_spec.lua`              | Word / boolean cycle, `+`/`-` increment/decrement, pack resolution.      |
| `transpose_spec.lua`          | Char/selection swap.                                                     |
| `sequence_spec.lua`           | Selection renumber: scanner (kind lock, start mode, prose boundaries), `range`/`span`, config + command wiring. |
| `multibyte_spec.lua`          | Byte-vs-character offsets: every write path driven over umlauts, CJK and emoji against hand-counted **byte** offsets. |
| `facade_spec.lua`             | `cascade/init.lua`: the runtime cycle-group commands, every domain and feature gate as its own decision, the three `:command` entry points, the count semantics. |
| `commands_spec.lua`           | `:Cascade*` commands exist; feature toggles gate actions; keymap wiring through real keypresses. |
| `bindings_spec.lua`           | `bindings/{init,keymaps,autocmds}.lua`: augroup idempotency across repeated `setup()`, the FileType and BufWritePre handlers fired for real, feature-family key suppression on both surfaces. |
| `usrcmds_spec.lua`            | Every `:Cascade` route run as a real Ex command: ranges, the bang, the enum and INT arguments, completion at each position. |
| `menu_spec.lua`               | `integrations/menu.lua`: the entry list, every gate, `submenu`, and an entry invoked end to end. |
| `lib_util_spec.lua`           | `cascade.util.lib`'s soft bridge to `lib.nvim` (notify/map/augroup), fallback and stubbed-present paths. |
| `health_spec.lua`             | `:checkhealth cascade` against a captured `vim.health`: every domain branch, the config-sanity warnings, the cross-pack clash report, and the dependency-missing branch with lib.nvim made to fail its `require`. |

## Adding a spec

Create `<name>_spec.lua` returning `function(H) … end` (use `H.eq` / `H.eq_lines` /
`H.ok` / `H.scratch` / `H.editable`) and add its filename to the `specs` list in
`run.lua`. `H.scratch` buffers are `buftype=nofile` (fine for exercising
`lists.*`/`cycle.*` modules directly); facade-level tests that go through
`cascade.*` functions (which gate on `writable()`) need `H.editable` instead.

Two practical notes:

- The facade's native-key fallbacks are **queued** with `nvim_feedkeys`, not
  executed immediately. A spec that triggers one (`cascade.o()` off a list
  item, `dispatch.try_or_native` with no handler) must flush with
  `nvim_feedkeys(vim.keycode("<Esc>"), "x", false)` before asserting, or the
  queued key lands in the middle of a later case.
- To test a count, bind the action to a throwaway key and feed the count with
  it (`vim.keymap.set("n", "<F13>", action)` then
  `nvim_feedkeys(vim.keycode("3<F13>"), "mtx", false)`). `vim.v.count1` cannot
  be set from Lua, and the dot-repeat trampoline stashes the count at keypress
  time, so calling the function directly always sees 1.

## No network, no subprocesses

Nothing here shells out and nothing touches the filesystem, because
cascade.nvim itself does neither: the plugin has no `vim.system`/`uv.spawn`
call, no `vim.fn.expand`/`mkdir`/`readfile`, and no path handling at all. It
reads buffer lines and writes buffer lines. That also means two of this fleet's
recurring failure families — Windows path-separator mismatches and unguarded
filesystem calls escaping as a raw `E739`/`E482` — are structurally absent
here rather than merely untested.

The only doubles in the suite are `package.loaded`/`package.preload`
substitutions used to make a dependency *absent* (the `lib.lua.*` fallbacks,
the `lib.nvim` composer for `health`'s error branch, `lib.nvim.logger` for the
debug-log fallback) and a captured `vim.notify` / `vim.health`. Everything else
runs against the real modules.

## Coverage

Measured with a `debug.sethook("l")` line probe over the whole suite: **83% of
executable lines in `lua/`**, up from 80% before this round. The per-module
figures matter more than the total:

| Module | before | after |
| --- | ---: | ---: |
| `health.lua` | 0% | 96% |
| `integrations/menu.lua` | 0% | 94% |
| `lists/cycle_type.lua` | 16% | 100% |
| `lists/shape.lua` | 68% | 100% |
| `cycle/packs/{fr,it,nl,pt,ru}.lua` | 0% | 100% |
| `util/lib.lua` | 60% | 87% |
| `lists/move.lua` | 68% | 97% |
| `dispatch/init.lua` | 69% | 95% |
| `lists/checkbox.lua` | 59% | 95% |
| `bindings/autocmds.lua` | 64% | 86% |
| `init.lua` | 62% | 81% |

### Deliberately not covered

- `@types/init.lua`, `cycle/types/init.lua`, `lists/types/init.lua` — pure
  `---@meta` annotation anchors with no runtime code.
- `config/DEFAULTS.lua` — a declarative data table with no branches. Its
  *values* are asserted where they matter (`health_spec` pins the shipped
  defaults it reports on, `packs_spec` pins the pack data, and
  `shape_cycle_type_spec` pins `lists.types`/`lists.cycle`/`lists.forms`), but
  the table itself is not walked for its own sake.
- `plugin/cascade.lua` — a load guard; under `-u NONE` it is never sourced.
- `ui.contextmenu.open()` and `ui.kit`'s float geometry — the renderers. The
  items cascade *hands* them are asserted (`menu_spec`), what they draw belongs
  to ui.nvim's own suite.
- Insert-mode `<CR>` continuation *as a keypress*. `continue.cr` is driven
  directly with a context; feeding a real `<CR>` in insert mode under
  `-u NONE` measures Neovim's input handling more than cascade's.

`bindings/keymaps.lua` and `bindings/usrcmds.lua` report ~55% line coverage,
which is a measurement artifact rather than a gap: both files are mostly one
large declarative table literal, and Lua's line hook attributes a multi-line
constructor to its opening line. Every key in `bind_list_buffer` and
`bind_preset_globals`, and every `:Cascade` route, is actually executed
(`bindings_spec`, `usrcmds_spec`).

## Bugs found during the coverage round

Six defects were found while writing this suite. The first two are **fixed**;
their assertions stayed on as regression guards. The other four are still
pinned at their **current** behaviour with a `BUG:`-prefixed message, since
each fix would be its own visible behaviour change.

1. **`lists/move.lua` used to inflate an ordered block's start number —
   fixed.** `dispatch_move_spec.lua`. `renumber.tree` deliberately anchors the
   base level on "its first item's start offset", so a list authored as
   `5. 6. 7.` stays at 5. Moving an item *into* first position broke that
   assumption: the line then standing first carried the next marker, so
   `1. 2. 3. 4.` became `2. 3. 4. 5.`, and again on the next press, with
   nothing repairing it — neither the on-save `renumber.all` nor
   `:Cascade renumber`, both anchored on the same wrong marker.
   `sort`/`reverse` reorder the same lines without drifting, which localized
   the defect to `move`. Fixed by having `move.line`/`move.selection` capture
   the block's base start *before* the `:move` (`renumber.peek_base_start`)
   and pass it through as `renumber.tree`'s new `forced_base_start`, instead
   of letting `tree` re-derive it from whichever line ends up first after the
   reorder. A deliberate `5. 6. 7.` list still stays anchored at 5 — the fix
   only changes which line's value counts as "first", not whether a
   non-1 start survives.
2. **The shipped `lists.cycle` default could not round-trip — fixed.**
   `shape_cycle_type_spec.lua`. `lists.types` defaulted to
   `{ "unordered", "digit" }` while `lists.cycle` defaults to
   `{ "-", "*", "+", "1.", "a)", "I." }`, so `<leader>ct` produced shapes the
   parser was never told to read: the cycle walked `- → * → + → 1. → a)` and
   dead-ended. Worse than the stall, the `a)` line had silently stopped being
   a list item (`marker.parse` returned nil), so renumbering, `<CR>`/`o`/`O`
   continuation, checkbox toggling and the block transforms all stopped
   seeing it, with no cascade key able to put it back. `lists.types` now
   defaults to `{ "unordered", "digit", "roman", "ascii" }` — every kind
   `lists.cycle` can produce, roman ordered *before* ascii (the reverse of
   `sequence.types`' order) because `lists.cycle` walks the same letter
   through both shapes in one sequence ("a)" then "I."): ascii-first would
   have parsed the cycle's own "I." output back as ascii (its pattern accepts
   either delimiter) and never matched the cycle's "I." entry, jumping the
   ring to an unrelated slot instead of closing it. Roman-first costs nothing
   for the ordinary case, since "a", "b", "c-as-ascii", etc. are simply not
   valid roman numerals and fall through to ascii exactly as before.
3. **Two of the three augroups are only cleared when their gate passes.** `bindings_spec.lua`.
   `bindings/autocmds.lua` promises "three autocmds, all idempotent (their
   augroups are cleared on every setup)". `setup_save_renumber` calls
   `lib.augroup(name)` first and gates afterwards — correct.
   `setup_list_keymaps` and `setup_hanging_indent` `return` on their gate
   *before* reaching `lib.augroup`, so a `setup()` with `keymaps.preset = false`,
   `lists.enable = false` or `lists.filetypes = {}` never empties the group and
   the previous setup's handlers stay live. Switching the preset or the list
   domain off does not take effect until Neovim restarts. Same family as
   pdfport.nvim's finding, opposite symptom: there a second `setup()` *added* a
   duplicate, here it fails to *remove* one.
4. **The runtime cycle-group commands mutate `config.DEFAULTS`.** `facade_spec.lua`.
   `lib.lua.config.deep_merge` copies only the top level of `base`, so any key
   the user did not override *is* the table inside
   `cascade.config.DEFAULTS` — `cycle.groups` included. `cycle_group_add`
   appends to the shipped defaults in place, so a group documented as
   "deliberately not persisted" survives a fresh `setup()`; `cycle_group_remove`
   deletes a shipped group for the rest of the session, and no re-`setup()`
   brings it back. DEFAULTS' own header says "Never mutate it at runtime". A
   user who supplies their own `cycle.groups` gets their own array mutated
   instead — the milder half of the same defect.
5. **`:Cascade indent N` / `:Cascade dedent N` ignore N.** `usrcmds_spec.lua`.
   The route declares `{ name = "levels", type = "INT" }` and its own desc says
   "arg = levels", but it hands `ctx.raw` to `run_indent_command`, which reads
   `tonumber(cmd.args)`. Under the composer `cmd.args` is the whole tail
   (`"indent 3"`), so `tonumber` is nil and the count degrades to 1. The
   correctly typed `ctx.args.levels` is parsed and thrown away. The keymap path
   (`<leader><A-Right>` with a count) works, because it reads `vim.v.count1`.
6. **`:Cascade cycle remove` truncates a value at the first space.** `usrcmds_spec.lua`.
   The mirror of `cycle add`, which explicitly appends `ctx.rest` for exactly
   this reason. `remove` reads only `ctx.args.value`, so a group added as
   `TODO,IN PROGRESS,DONE` cannot be removed by the member that made the tail
   necessary. Workaround: remove by a single-word member.

### Pinned as behaviour, not defects

- `dispatch.try` accepts *any* truthy handler return as "handled", not only
  `true` (the guard is `ok and handled`). `dispatch_move_spec.lua`.
- `lists.types`' order decides the `ascii`/`roman` overlap: a single `I` is both
  a Roman numeral and the 9th letter, and `d)` is claimed by `roman` (500)
  whenever `roman` is listed first. `shape_cycle_type_spec.lua`.
- `cycle_type`'s "current shape is not in the ring" branch sets the index to 1
  and *then* applies the direction, so it lands on the second entry going
  forward and on the last going back. `shape_cycle_type_spec.lua`.
- `packs.resolve` caches its result per pack list *including* a partial one, so
  a pack module that failed to load would stay failed for the session. Not
  reachable today (the packs ship with the plugin), noted because the shape is
  a known trap.

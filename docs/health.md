# Health

```vim
:checkhealth cascade
```

Read-only: it reports, it never changes anything. It is the fastest way to
tell a configuration problem from a cascade bug, and the only place that names
the words your cycle packs make unreachable.

## What it reports

### Neovim version

`OK` for 0.9+, a warning below that. cascade targets 0.9 and uses no API
above it.

### lib.nvim

| Line | Meaning |
| --- | --- |
| `OK  lib.nvim detected (:Cascade command layer + lib.map/lib.notify available)` | Everything works. |
| `ERROR  lib.nvim not found — :Cascade will fail to load` | The **hard** half of the dependency is missing. `setup()` itself aborts — both `:Cascade` and the preset keymaps are built through `lib.nvim`. Install `StefanBartl/lib.nvim` — see [`installation.md`](installation.md#requirements). |

### which-key

Informational either way. cascade's mappings carry their own `desc`, so
which-key needs no registration for the individual keys; when it is installed,
`<leader>c` is labelled as a group.

### debug

Reports whether `cascade.debug` is on, and whether `lib.nvim.logger` was found
to carry the output (otherwise `vim.notify` at DEBUG level). See
[`configuration.md`](configuration.md#debug).

### lists

`OK  lists: enabled for { … }` lists the filetypes the list keys attach to.
Then the sanity checks — each one names a feature that is silently dead if the
option it depends on is empty:

| Warning | Consequence |
| --- | --- |
| `lists.checkbox.states is empty` | checkbox toggling disabled |
| `lists.cycle is empty` | marker-type cycling disabled |
| `lists.forms is empty` | form rotation disabled |

Plus one info line for renumbering: either the triggers in effect
(`renumber: on (edit, save)`) or `renumber: off — only manual :Cascade
renumber re-sequences lists`.

### cycle

```
OK    cycle: enabled (all filetypes), N own groups + M from packs
INFO  packs: en, de, dev (order = precedence)
INFO  number fallback: native <C-y>/<C-x> on numeric tokens
```

The one that earns the command:

```
WARNING  2 word(s) appear in more than one cycle group:
  "no" → { no, yes } wins, { no, sí } unreachable
```

A word may only live in **one** group of the effective set — the lookup takes
the first, so any later group holding it can never be reached. This is easy to
hit as soon as several language packs are on (`no` is English *and* Spanish,
`ja` is German *and* Dutch). The shipped default `{ "en", "de", "dev" }` is
collision-free; the warning appears only for combinations you chose. At most
eight collisions are listed, then a count. See
[`configuration.md`](configuration.md#cycle-packs) for the precedence rule
that decides the winner.

### sequence

Enabled/disabled, the kind order (`types`), and which `start` mode is in
effect — `keep` (the first hit sets the start value) or `one` (every run
restarts at 1/a/i).

### transpose

Enabled or disabled. Always all filetypes; there is no filetype option.

## What it does *not* report

**Per-feature status.** The domain lines say whether `lists`, `cycle`,
`sequence` and `transpose` are on — not whether an individual
`lists.features.*` / `cycle.features.*` / `transpose.features.*` switch is.
If a single mapping feels dead while its domain reports `OK`, read the feature
switch in your config directly; a disabled feature makes the *action itself* a
no-op, not just the key. See
[`configuration.md`](configuration.md#feature-toggles).

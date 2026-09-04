# Command reference

cascade registers exactly **one** user command, `:Cascade <subcommand>`, built
via [`lib.nvim.bindings.usercmd.composer`](https://github.com/StefanBartl/lib.nvim)
with `<Tab>` completion. It is defined by `setup()` regardless of
`keymaps.preset`.

For the one-line-per-command cheatsheet, see
[`BINDINGS.md`](BINDINGS.md#user-commands). This page carries the usage and
the examples.

## Two things to know first

**The bang attaches to the verb, not the subcommand.** `:Cascade! rotate`,
not `:Cascade rotate!` — Vim's `!` always binds to the command name itself,
so collapsing the old `:CascadeRotate`/`:CascadeSort`/… family into one verb
moved it there. Subcommands that have no backward direction (`reverse`,
`strip`, `indent`, `dedent`, `renumber`) ignore a bang if you type one.

**The list transforms are range-aware, the cycle subcommands are not.**
Without a range, `rotate`/`sort`/`reverse`/`strip`/`indent`/`dedent`/`renumber`
act on the list block at the cursor; with a range (`:'<,'>` from Visual mode,
or `:10,20`) on those lines. `:Cascade cycle …` edits configuration, not
text, and takes no range.

## List transforms

### `:Cascade rotate [next|prev]`

Rotates the block or range through the forms in `lists.forms` — by default
`1.` → `1. [ ]` → `- [ ]` → `-`. Existing checkbox states (`[x]`) are
preserved across the change and ordered targets are renumbered automatically.

- **Bang / `prev`:** rotate backward. `:Cascade! rotate` and
  `:Cascade rotate prev` are the same thing.
- **Gate:** `lists.features.rotate`.

```vim
:Cascade rotate            " numbered list -> numbered checklist
:'<,'>Cascade rotate       " only the selected lines
:Cascade! rotate           " backward
```

### `:Cascade sort`

Sorts the block or range alphabetically and renumbers it.

- **Bang:** `:Cascade! sort` sorts Z–A.
- **Gate:** `lists.features.sort`.

### `:Cascade reverse`

Reverses the order of the items in the block or range and renumbers.

- **Gate:** `lists.features.reverse`.

### `:Cascade strip`

Removes `[ ]`/`[x]` from every item in the block or range; the markers stay.

- **Gate:** `lists.features.strip`.

### `:Cascade indent [n]` / `:Cascade dedent [n]`

Shifts the line or range by `n` levels (default 1) and renumbers every indent
level the change touches — a deeper level starts fresh at `1.`, a shallower
one continues, and the level left behind closes its gap.

Works in **any** filetype; the renumbering half is what is skipped outside
`lists.filetypes`, so elsewhere it is a plain shift.

- **Gate:** `lists.features.indent` (for the renumbering).

```vim
:Cascade indent 2          " current line, two levels
:'<,'>Cascade dedent       " the selected lines, one level
```

### `:Cascade renumber [all|selection]`

| Form | What it renumbers |
| --- | --- |
| `:Cascade renumber` | The ordered list block at the cursor, or the given range. |
| `:Cascade renumber all` | Every list block in the buffer, each numbered independently. |
| `:Cascade renumber selection` | The **ordinal tokens inside the lines** rather than the list markers — the `sequence` domain, gated by `sequence.enable`. See [`FEATURES/SEQUENCE.md`](FEATURES/SEQUENCE.md). |

`renumber selection` is the Ex pendant of `<leader>cR` for the linewise case.
An Ex range is always linewise in Vim, so a mid-line charwise selection has to
go through the keymap — the command would discard the columns.

## Cycle groups at runtime

`cycle.groups` is otherwise config-only, so trying out a group meant editing
the config and reloading. These three subcommands edit the live table that
`word_cycle.groups_for` reads on every keypress, so a change takes effect
immediately.

**Deliberately not persisted.** They last for the session; the config file
stays the single source of truth for groups worth keeping.

### `:Cascade cycle add {values}`

Comma-separated values. The **whole tail** is taken, not just the first
token, so a value may contain spaces:

```vim
:Cascade cycle add alpha,beta,gamma
:Cascade cycle add TODO, IN PROGRESS ,DONE
```

Values are trimmed and de-duplicated. If fewer than two distinct values
remain, the group is refused with a warning — a cycle of one cannot cycle.

### `:Cascade cycle list`

Reports the groups in effect for the current buffer: the global `cycle.groups`
plus `cycle.per_filetype[ft]`, marked as such. These are separate config keys,
so reading either alone answers the wrong question. Pack contents are *not*
listed — `:checkhealth cascade` reports those, with their collisions.

### `:Cascade cycle remove {value}`

Drops the first group containing the value you name, so any member of a group
identifies it:

```vim
:Cascade cycle remove beta
```

## Autocommands

Three, all registered by `setup()` and all idempotent — their augroups are
cleared on every call. They are listed in
[`BINDINGS.md`](BINDINGS.md#autocommands).

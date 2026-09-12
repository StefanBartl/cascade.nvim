# Quickstart

The first thing to run after installing.

Open a Markdown file, type `1. first` and press `<CR>` — you get `2.` for
free. Press `<C-y>` on a `true` anywhere in any buffer and it becomes `false`.
That is the whole idea; everything else is more of it.

The command tree does the same jobs without keymaps:

```vim
:Cascade rotate            " numbered list -> numbered checklist -> bullet
:Cascade renumber          " renumber the list block at the cursor
:Cascade renumber selection " renumber the ordinals inside the selected lines
:Cascade indent 2          " indent the current line two levels, renumbering
```

Full command reference, including every subcommand's args and range
behavior: [commands.md](commands.md).

Verify your setup any time with:

```vim
:checkhealth cascade
```

[health.md](health.md) explains every line it can print.

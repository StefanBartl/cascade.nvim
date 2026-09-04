# cascade.nvim documentation

What is here, and which question each page answers.

## Getting it running

| Page | Answers |
| --- | --- |
| [installation.md](installation.md) | Requirements, why `lib.nvim` is the one hard dependency, which loading strategy fits which use, and the spec for every plugin manager |
| [configuration.md](configuration.md) | Every `setup()` option and its default — plus the three things the defaults alone do not explain: how the cycle packs take precedence over each other, which domains are global and which are filetype-scoped, and when renumbering actually runs |
| [health.md](health.md) | What each line of `:checkhealth cascade` means, including the one warning that is hard to get any other way: which words your combination of cycle packs makes unreachable |

## Using it

| Page | Answers |
| --- | --- |
| [BINDINGS.md](BINDINGS.md) | Every keymap, user command and autocommand this plugin registers, including how to wire the optional context menu |
| [keymaps.md](keymaps.md) | The other half of that question: which *function* to bind, for wiring your own keys instead of taking the preset — and why counts mean different things on different keys |
| [commands.md](commands.md) | `:Cascade <subcommand>` in full, with examples — including the three cycle-group subcommands that edit configuration rather than text |
| [WORKFLOW.md](WORKFLOW.md) | The different question: not what each feature does, but how they combine — which key to reach for when a line is *almost* the list item you want |

## Why it is the way it is

| Page | Answers |
| --- | --- |
| [FEATURES/](FEATURES/README.md) | One page per area — cycling, lists, sequence renumbering, transposing — and what separates them: how much the plugin has to recognise before it can act, which is also why some are global and some are filetype-scoped |
| [architecture.md](architecture.md) | The detect → advance → fall back chain all four domains share, where each module sits, and exactly how much of `lib.nvim` is required versus merely used |

## Elsewhere

`:h cascade` carries the same reference material in Vim help form
(`doc/cascade.txt`). A module map is not shipped in the repository — it is
generated on demand with `:DocMap` and would be stale the moment it was
committed.

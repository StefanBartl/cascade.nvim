# Configuration

Every `setup()` option and its default. The table below is the complete
`config/DEFAULTS.lua`, not an excerpt; `:h cascade-config` carries the same
reference in Vim help form.

## Table of contents

- [Defaults](#defaults)
- [lists](#lists)
- [cycle](#cycle)
- [sequence](#sequence)
- [transpose](#transpose)
- [keymaps](#keymaps)
- [debug](#debug)
- [Cycle packs](#cycle-packs)
- [Scopes: global vs. filetype-scoped](#scopes-global-vs-filetype-scoped)
- [Renumber timing](#renumber-timing)
- [Feature toggles](#feature-toggles)

## Defaults

```lua
require("cascade").setup({
  lists = {
    enable = true,                           -- master switch for the list domain
    features = {                             -- toggle each feature individually
      continue = true, checkbox = true, cycle_type = true,
      rotate = true, sort = true, reverse = true, strip = true,
      indent = true, move = true,
      bullet_toggle = true,                  -- also gates <A-*> (star_toggle)
      number_toggle = true, checkbox_toggle = true,
    },
    filetypes = {                            -- prose/markup filetypes (lists no-op elsewhere)
      "markdown", "markdown.mdx", "mdx", "text", "txt", "tex", "plaintex",
      "latex", "norg", "org", "rst", "asciidoc", "asciidoctor", "typst",
      "quarto", "pandoc", "vimwiki", "gitcommit", "mail",
    },
    types = { "unordered", "digit" },        -- detection order; "ascii"/"roman" are opt-in
    unordered_markers = { "-", "*", "+" },
    per_filetype_patterns = {},              -- custom markers, tried before `types`
    cycle = { "-", "*", "+", "1.", "a)", "I." },  -- cycle_type (single line)
    forms = { "1.", "1. [ ]", "- [ ]", "-" },     -- form rotation (block/visual)
    checkbox = { states = { " ", "x", "~" } },    -- N-state cycle (open -> done -> in progress)
    continue = {
      delete_empty = true,                   -- <CR> on an empty bullet ends the list
      hanging_indent = true,                 -- set 'formatlistpat'/'formatoptions' for gq
    },
    renumber = {                             -- WHEN it renumbers automatically
      enable = true,
      on = { "edit", "save" },               -- "edit" = immediately, "save" = on :w (safety net)
      blank_break = 0,                       -- blank lines that end a block (0 = any blank breaks it)
    },
    precision = "off",                       -- "treesitter" skips list actions inside fenced code
    precision_nodes = {},                    -- per-filetype skip-node overrides
  },
  cycle = {
    enable = true,
    features = { word = true, date = true, letter = true, char = true },
    filetypes = nil,                         -- nil = all filetypes
    number_fallback = true,                  -- native <C-a>/<C-x> on numbers
    packs = { "en", "de", "dev" },           -- built-in bundles; order = precedence
    groups = {                               -- your own groups; checked BEFORE the packs
      { ".", "/", "\\" },
      { "==", "!=" }, { "&&", "||" }, { "<", ">" }, { "+", "-" },
    },
    per_filetype = {},                       -- e.g. lua = { { "pairs", "ipairs" } }
  },
  sequence = {                               -- renumber INSIDE a selection (global)
    enable = true,
    start = "keep",                          -- "keep" = start at the first hit; "one" = restart at 1/a/i
    types = { "digit", "ascii", "roman" },   -- order the FIRST hit is classified in; it locks the kind
  },
  transpose = {
    enable = true,
    features = { char = true, word = true },
  },
  keymaps = {
    preset = false,                          -- true binds the opinionated default keys
    globals = {},                            -- per-action key overrides, everywhere
    list = {},                               -- per-action key overrides, inside a list buffer
  },
  debug = false,                             -- log detect/advance/fallback decisions
})
```

## lists

| Key | Type | Meaning |
| --- | --- | --- |
| `lists.enable` | boolean | Master switch for the list domain. |
| `lists.features` | table | Per-feature on/off: `continue`, `checkbox`, `cycle_type`, `rotate`, `sort`, `reverse`, `strip`, `indent`, `move`, `bullet_toggle`, `number_toggle`, `checkbox_toggle`. A missing key counts as enabled. `bullet_toggle` also gates `<A-*>`. |
| `lists.filetypes` | string[] | Filetypes the list keys attach to. Actions no-op on a line without a marker, so a broad list is harmless. |
| `lists.types` | string[] | Enabled marker kinds in detection order: `"unordered"`, `"digit"`, `"ascii"`, `"roman"`. `ascii`/`roman` are opt-in because a lone letter is ambiguous; with a mix enabled the order in `types` decides. |
| `lists.unordered_markers` | string[] | Accepted bullet characters. |
| `lists.per_filetype_patterns` | table<string, string[]> | Custom, non-incrementing marker patterns per filetype, tried before the built-in kinds — e.g. LaTeX's `\item`. Each pattern needs exactly two Lua-pattern captures (marker token, then the rest after the separating whitespace): `"^(\\item)%s(.*)$"`. Matches are always an "unordered" kind. |
| `lists.cycle` | string[] | Marker shapes `cycle_type` steps through, one line at a time. Templates: `a`/`A` = alpha, `i`/`I` = roman. |
| `lists.forms` | string[] | Form rotation over a block/selection: a marker shape plus an optional `[ ]` checkbox. |
| `lists.checkbox.states` | string[] | The N-state checkbox cycle. Multi-byte states (emoji) work if listed. |
| `lists.continue.delete_empty` | boolean | `<CR>` on an already-empty bullet removes it and ends the list. |
| `lists.continue.hanging_indent` | boolean | Sets buffer-local `formatlistpat` (derived from `types`/`unordered_markers`) and adds `n` to `formatoptions`, so native `gq` hang-indents a wrapped item under its text. |
| `lists.renumber.*` | table | See [Renumber timing](#renumber-timing). |
| `lists.precision` | `"off"` \| `"treesitter"` | `"treesitter"` skips single-cursor list actions inside a configured skip node (default: a fenced code block). Every check is `pcall`-wrapped — a missing parser falls back to `"off"` behaviour. |
| `lists.precision_nodes` | table<string, string[]> | Per-filetype overrides for those skip-node types. |

## cycle

| Key | Type | Meaning |
| --- | --- | --- |
| `cycle.enable` | boolean | Master switch for the cycle domain. |
| `cycle.features` | table | `word`, `date`, `letter`, `char`. |
| `cycle.filetypes` | string[] \| nil | `nil` (default) means every filetype. |
| `cycle.number_fallback` | boolean | Fall back to native `<C-a>`/`<C-x>` on a numeric token. |
| `cycle.packs` | string[] | Built-in bundles: `"en"`, `"de"`, `"es"`, `"fr"`, `"it"`, `"pt"`, `"nl"`, `"ru"`, `"dev"`. See [Cycle packs](#cycle-packs). |
| `cycle.groups` | string[][] | Your own groups, checked **before** every pack. |
| `cycle.per_filetype` | table<string, string[][]> | Extra groups merged in for one filetype. |

Groups can also be added and dropped for the running session with
`:Cascade cycle add|list|remove` — see
[`commands.md`](commands.md#cycle-groups-at-runtime).

## sequence

| Key | Type | Meaning |
| --- | --- | --- |
| `sequence.enable` | boolean | Master switch for the selection-renumber domain. |
| `sequence.start` | `"keep"` \| `"one"` | `"keep"` takes the start value from the first hit; `"one"` always restarts at 1/a/i. |
| `sequence.types` | string[] | Kinds tried, in order, to classify the *first* hit — which then locks the kind for the rest of the run. A single letter is read as `ascii` before `roman` by default (`a) b) c)` is the commoner case); put `"roman"` first for `i./ii./iii.`. |

## transpose

| Key | Type | Meaning |
| --- | --- | --- |
| `transpose.enable` | boolean | Master switch for the transpose domain. |
| `transpose.features.char` | boolean | Char swap, and the char variant of the selection swap. |
| `transpose.features.word` | boolean | Word swap, and the word variant of the selection swap. |

## keymaps

| Key | Type | Meaning |
| --- | --- | --- |
| `keymaps.preset` | boolean | `false` (default) binds nothing at all. |
| `keymaps.globals` | table<string, string\|string[]\|false> | Per-action overrides for the keys that work everywhere. |
| `keymaps.list` | table<string, string\|string[]\|false> | The same, for the keys bound inside a buffer whose filetype matched. |

Each key is an individually overridable named action, so moving or dropping
one costs a line rather than a fork of the preset:

```lua
keymaps = {
  preset = true,
  globals = { move_up = "<A-k>", cycle_char_next = "<C-M-y>" },  -- move one, drop an alias
  list = { sort = false },                                       -- drop one
}
```

The action names are the ones in [`keymaps.md`](keymaps.md); the feature
switches above still gate their whole group.

## debug

`debug = true` logs cascade's central decision points — `dispatch.try`'s
handler chain and the `lists_active()` gate — through `lib.nvim.logger` when
that is available, otherwise `vim.notify` at DEBUG level. Off by default, and
the check itself is a single boolean read when off.

## Cycle packs

`cycle.packs` switches whole bundles of word groups on by name instead of
pasting them into `cycle.groups`. Each is one small file under
[`lua/cascade/cycle/packs/`](../lua/cascade/cycle/packs) — open one to see
exactly what it holds, or as a template for your own.

| Pack | Contents |
| --- | --- |
| `en` *(default)* | `true`/`false`, `on`/`off`, `yes`/`no`, `show`/`hide`, `start`/`stop`, `up`/`down`, … |
| `de` *(default)* | `wahr`/`falsch`, `ja`/`nein`, `ein`/`aus`, `sichtbar`/`unsichtbar`, `oben`/`unten`, … |
| `dev` *(default)* | `dev`/`stage`/`prod`, `todo`/`doing`/`done`, `low`/`medium`/`high`, `draft`/`review`/`final`, `alpha`/`beta`/`rc`/`stable`, `debug`/`info`/`warn`/`error`, `get`/`post`/`put`/`patch`/`delete`, `xs`…`xl` |
| `es` `fr` `it` `pt` `nl` `ru` | The same boolean/state vocabulary in those languages. Opt-in. |

```lua
cycle = {
  packs = { "de", "en", "dev", "fr" },              -- add French, and let German win ties
  groups = { { "wahr", "vielleicht", "falsch" } },  -- your own; beats every pack
}
```

**Precedence is list order, most specific first:** `cycle.groups` →
`cycle.per_filetype[ft]` → `cycle.packs` (in the order you list them). A word
only ever belongs to the *first* group that contains it, so with
`{ "en", "es" }` the word `no` cycles to `yes`, and with `{ "es", "en" }` it
cycles to `sí`. The shipped default `{ "en", "de", "dev" }` is collision-free;
`:checkhealth cascade` names every word your own combination makes
unreachable. `packs = {}` disables all of them and leaves only your `groups`.

> **Not shipped:** Chinese, Japanese and other scripts without word
> separators. cascade finds the token under the cursor with `\k\+`, and
> `'iskeyword'`'s `@` class matches every alphabetic character — so an
> unspaced run of CJK is captured as *one* token rather than a word, and would
> never match a group entry. Cyrillic (`ru`) is fine: it uses spaces.

## Scopes: global vs. filetype-scoped

cascade's domains have deliberately different scope, and this is the single
most common source of surprise.

- **`cycle`** (word/boolean, date, letter, in-word char, number fallback) is
  **global** — `cycle.filetypes = nil` means *all* filetypes. `true`↔`false`,
  `on`↔`off` and `<C-y>`/`<C-x>`/`+`/`-` work in `.txt`, `.lua`, `.md`,
  everywhere. Narrow it with e.g. `cycle.filetypes = { "lua", "markdown" }`.
- **`lists`** (continue, checkbox, cycle_type, rotate, sort, reverse, strip,
  renumber) is scoped to `lists.filetypes` — list markers are prose/markup
  specific. List actions **no-op** on lines without a marker, so a broad
  filetype list is harmless.
- **`sequence`** (renumber inside a selection) is **global**, with no filetype
  option at all — it never looks at list markers, only at ordinal tokens in
  the selected text.
- **`transpose`** (char/word/selection swap) is **global**, with no filetype
  option at all — swapping characters is filetype-agnostic by nature.
- **Indent/dedent** and **move** are effectively **global**: list-aware inside
  `lists.filetypes` (with renumber), plain `>>`/`<<` or `:move` elsewhere.

| Feature | Scope |
| --- | --- |
| Word/boolean cycle, dates, letters, numbers | global (every filetype) |
| Indent/dedent, move | global (renumber only in `lists.filetypes`) |
| Continue, cycle_type, rotate, sort, reverse | `lists.filetypes` |
| Checkbox, strip | `lists.filetypes` |
| Quick bullet/number/checkbox toggle | `lists.filetypes` (work without an existing marker) |
| Char/word/selection swap | global (no filetype option) |

## Renumber timing

`lists.renumber.on` controls *when* renumbering happens — `{ "edit" }`
(immediately after indent/move/continue/…), `{ "save" }` (on `:w` via
`BufWritePre`, over the whole buffer) or both. Both are on by default:
"edit" keeps in-progress edits clean, "save" is the safety net for lists that
never produced an edit event — pasted in, typed by hand with every marker left
at `1.`, or produced by another plugin. `enable = false` turns everything off,
leaving `:Cascade renumber` / `<leader>cr` as the only way to renumber. A plain
boolean is still accepted (`true` = `{ "edit", "save" }`).

**Continuation paragraphs.** A non-marker, non-blank line (a wrapped paragraph
or a note under an entry) never breaks the sequence, no matter its own
indent — it is left untouched and the numbering carries on past it, matching
Markdown's "lazy continuation": without a blank line separating it from the
item above, it belongs to that item. A **blank line**, by contrast, ends the
block, and the next list starts a fresh sequence with its own start offset.

```markdown
1. Product Module: ...
Note on Module Export: ...        ← no blank line, sequence continues
1. Tosca Version: ...             ← renumbered to 2, not left at 1
```

Raise `lists.renumber.blank_break` to tolerate blanks inside a block: `1`
gives the CommonMark "loose list" reading (a single blank line between items
still counts as one list; two or more end it).

## Feature toggles

Every feature can be switched off individually via `lists.features.*`,
`cycle.features.*` or `transpose.features.*`. A disabled feature no longer
runs its action **and** the preset does not bind its keys — so keys with a
native meaning (`<CR>`, `<A-Right>`, `<C-y>`, `+`/`-`) simply stay native.
Missing entries count as enabled.

This is not the same as leaving a key unbound: a disabled feature makes the
*action itself* a no-op, so a key you bound by hand
(`vim.keymap.set("n", "<leader>cf", cascade.rotate_form_next)`) would also
silently do nothing. If a mapping feels dead, check the feature switch before
suspecting the mapping.

`:checkhealth cascade` reports enabled/disabled **per domain** — not yet per
individual feature.

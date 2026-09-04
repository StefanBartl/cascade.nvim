# Architecture

How cascade is put together, and the two decisions the layout follows from:
**one pattern for four domains**, and **one hard dependency, everything else
soft**.

## The pattern

Every action in cascade is the same three steps:

```
detect the context under the cursor  →  advance it one step  →  otherwise
fall back to the native key
```

`dispatch/init.lua` is that chain of responsibility, shared by all domains:
given an ordered list of handlers, it runs each against one context object
until one reports that it handled the action; if none do, it feeds the native
key so the editor's default behaviour survives untouched. That is why `+` on a
line with nothing cyclable still moves to the first non-blank of the next
line, and why `<C-y>` on an unknown word leaves the word alone.

`core/context.lua` is the context object: buffer handle, 0-based cursor row and
column, the current line, the filetype — built **once per action** rather than
scattering `nvim_*` calls through every handler. `core/patterns.lua` memoizes
the Lua-pattern fragments derived from config, which are stable for a session.

Two places are instrumented for `cascade.debug`: `dispatch.try`'s handler
chain and `lists_active()` in `init.lua` — the detect/advance/fallback
decision and the filetype gate, which between them explain almost every
"why did nothing happen".

## Layout

```
cascade.nvim/
  plugin/cascade.lua      -- load guard (vim.g.loaded_cascade)
  lua/cascade/
    init.lua              -- setup() + the action facade every keymap binds to
    health.lua            -- :checkhealth cascade
    @types/init.lua       -- LuaLS classes for the whole config surface
    config/
      DEFAULTS.lua        -- single source of truth for every default
      init.lua            -- deep-merge + get(path)
    core/
      context.lua         -- one context object per action
      patterns.lua        -- memoized marker patterns
      treesitter.lua      -- opt-in skip-node check (pcall-guarded)
    dispatch/init.lua     -- try handlers in order -> native fallback
    lists/                -- marker, continue, renumber, checkbox, quick_toggle,
                             cycle_type, indent, move, transform, shape, format,
                             roman, alpha
    cycle/                -- token, word_cycle, date, letter, packs/
    sequence/renumber.lua -- ordinals inside a selection (no marker parsing)
    transpose/            -- char, word
    integrations/menu.lua -- nvzone/menu entries, no dependency on it
    bindings/             -- keymaps, usrcmds (:Cascade), autocmds
    util/
      lib.lua             -- the guarded lib.nvim bridge
      dotrepeat.lua       -- operatorfunc trampoline for `.`
  doc/cascade.txt         -- :h cascade
  docs/                   -- this folder
  TESTS/                  -- busted-style specs, run via TESTS/run.lua
```

## Why four domains and not one

The four domains differ in **what has to be recognised before anything can
happen**, and that difference is why some are global and some are not:

| Domain | Recognises | Scope |
| --- | --- | --- |
| `cycle` | one token under the cursor | global |
| `transpose` | one character or word and its neighbour | global |
| `lists` | a list marker at the start of the line | `lists.filetypes` |
| `sequence` | ordinal tokens anywhere in a selection | global |

`sequence` is a separate domain rather than a mode of `lists.renumber` for a
structural reason, not a stylistic one: `lists/marker.lua` requires the number
to be the line's **first** token, so a numbered headline (`### 2. …`) or a
number mid-sentence is invisible to the list parser. Two different questions,
two parsers. See [`FEATURES/SEQUENCE.md`](FEATURES/SEQUENCE.md).

## Safety and performance

- **Pure line scan by default.** No Treesitter dependency; `lists.precision =
  "treesitter"` is opt-in for the one case a line scan is genuinely blind to
  (a `- flag` inside a fenced code block), and every check there is
  `pcall`-wrapped so a missing parser degrades to the default behaviour.
- **No `CursorMoved`/`TextChanged` autocmds.** All work is triggered by
  explicit keys or commands. The three autocmds cascade does register are
  listed in [`BINDINGS.md`](BINDINGS.md#autocommands), and all three are
  idempotent — their augroups are cleared on every `setup()`.
- **`pcall` around every buffer mutation**, one context object per action,
  memoized patterns.
- **Dot-repeat** goes through `util/dotrepeat.lua`, an `operatorfunc`
  trampoline. Counts are captured *before* the trampoline, because it does not
  carry `vim.v.count1` through to the deferred work.

## The lib.nvim boundary

[`lib.nvim`](https://github.com/StefanBartl/lib.nvim) is cascade's one
**required** dependency, and the boundary is deliberately narrow:

| Used for | Hard or soft |
| --- | --- |
| `lib.nvim.bindings.usercmd.composer` — the `:Cascade` verb | **hard**; without it the command fails to load |
| `lib.nvim.bindings.keymap` — the preset registry | hard, alongside the composer |
| `lib.nvim.selection` — multi-line charwise spans | hard, bridged directly |
| `lib.nvim.notify`, `lib.nvim.bindings.keymap` (the `map` helper), `lib.nvim.bindings.autocmd.augroup`, `lib.nvim.logger`, `lib.nvim.dotrepeat`, `lib.lua.strings.case`, `lib.lua.numeral` | **soft** — used when present, native fallback otherwise |

`util/lib.lua` is the whole bridge: a `try_require` per module, and a native
implementation behind each soft one. Everything in the soft row works without
`lib.nvim` on the runtimepath; nothing in the hard rows does. `:checkhealth
cascade` reports which situation you are in — see [`health.md`](health.md).

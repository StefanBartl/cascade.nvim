---@module 'cascade.config.DEFAULTS'
--- Immutable default configuration for cascade.nvim.
---
--- Single source of truth for every configurable value. `cascade.config`
--- deep-merges user options on top of this table. Never mutate it at runtime.

---@type CascadeConfig
local DEFAULTS = {
  lists = {
    enable = true,
    -- Per-feature switches. Disabling one stops its keymap action (and the
    -- preset stops binding its keys); keys with a native meaning fall back to it.
    features = {
      continue = true, -- <CR>/o/O continuation + empty-bullet deletion
      checkbox = true, -- toggle/cycle checkbox
      cycle_type = true, -- cycle a single item's marker shape
      rotate = true, -- block/visual form rotation
      sort = true, -- block/visual A-Z sort
      reverse = true, -- block/visual reverse order
      strip = true, -- block/visual remove checkboxes
      indent = true, -- indent/outdent + level-aware renumber
      move = true, -- move line/selection up/down + renumber
      bullet_toggle = true, -- quick "-" bullet on/off, no existing marker required
      number_toggle = true, -- quick "1." marker on/off, no existing marker required
      checkbox_toggle = true, -- quick "- [ ]" insert/cycle/remove, no existing marker required
    },
    -- Prose / markup filetypes the list features attach to. List actions no-op
    -- on lines without a marker, so a broad set is safe. The word/number cycle
    -- lives in the `cycle` domain and is global (every filetype) by default.
    filetypes = {
      "markdown",
      "markdown.mdx",
      "mdx",
      "text",
      "txt",
      "tex",
      "plaintex",
      "latex",
      "norg",
      "org",
      "rst",
      "asciidoc",
      "asciidoctor",
      "typst",
      "quarto",
      "pandoc",
      "vimwiki",
      "gitcommit",
      "mail",
    },
    types = { "unordered", "digit" },
    unordered_markers = { "-", "*", "+" },
    -- Custom, non-incrementing marker patterns per filetype, tried before the
    -- built-in kinds (unordered/digit/ascii/roman) -- e.g. LaTeX's `\item`,
    -- which isn't any of those. Each pattern needs exactly two Lua-pattern
    -- captures: the marker token, then the rest of the line after the
    -- required separating whitespace, e.g. `"^(\\item)%s(.*)$"`. Matches
    -- are always treated as an "unordered" kind (fixed token, never
    -- renumbered) -- an ordered custom marker should use `types` instead.
    per_filetype_patterns = {},
    cycle = { "-", "*", "+", "1.", "a)", "I." },
    forms = { "1.", "1. [ ]", "- [ ]", "-" },
    checkbox = {
      states = { " ", "x", "~" },
    },
    continue = {
      delete_empty = true,
      -- Sets buffer-local 'formatlistpat' (from `types`/`unordered_markers`)
      -- and adds `n` to 'formatoptions' on the configured list filetypes, so
      -- native `gq`/auto-wrap hang-indents a wrapped item under its text
      -- instead of back at the margin. false = leave both options alone.
      hanging_indent = true,
    },
    -- When ordered lists are auto-renumbered.
    --   enable:      master switch (false = only manual :Cascade renumber)
    --   on:          any of "edit" (right after indent/move/continue/...) and
    --                "save" (BufWritePre). Both are on by default: "edit"
    --                keeps in-progress edits clean immediately, "save" is the
    --                safety net for everything "edit" can't see — a pasted
    --                block, a list typed by hand with every marker left at
    --                "1.", a plugin/external edit. A plain boolean is also
    --                accepted: true = {"edit", "save"}.
    --   blank_break: how many *consecutive* blank lines a list block tolerates
    --                before they end it. 0 (default) = any blank line separates
    --                two lists, so each is numbered on its own. Raise to 1 for
    --                the CommonMark "loose list" reading (a single blank line
    --                between items still counts as one list).
    renumber = {
      enable = true,
      on = { "edit", "save" },
      blank_break = 0,
    },
    -- Opt-in Treesitter precision: "off" (default) is cascade's plain
    -- line-scan everywhere, blind to syntax. "treesitter" additionally skips
    -- single-cursor list actions (continuation, toggles, single-line
    -- indent, ...) when the cursor sits inside a configured "skip" node
    -- (default: a markdown/norg fenced code block) -- see
    -- cascade.core.treesitter for the default node types and the pcall-safe
    -- fallback when no parser is installed.
    precision = "off",
    precision_nodes = {},
  },

  cycle = {
    enable = true,
    features = {
      word = true, -- cycle the word/boolean under the cursor
      date = true, -- step the year/month/day segment of an ISO date (YYYY-MM-DD) under the cursor
      letter = true, -- cycle a single a-z/A-Z letter under the cursor through the alphabet (case preserved)
      char = true, -- <C-M-y>/<C-M-x>: step the character under the cursor through the alphabet, inside a word too
    },
    filetypes = nil,
    number_fallback = true,
    -- Named bundles of word groups, switched on by name instead of pasted
    -- into `groups` below. Language packs ("en", "de", "es", "fr", "it",
    -- "pt", "nl", "ru") carry that language's boolean/state vocabulary;
    -- "dev" carries the language-neutral developer cycles (dev/stage/prod,
    -- todo/doing/done, log levels, HTTP verbs, ...). See
    -- cascade/cycle/packs/ for the contents -- one small file per pack.
    --
    -- The ORDER is the precedence: the first group a word appears in wins, so
    -- with { "es", "en" } a Spanish "no" cycles to "sí", and with
    -- { "en", "es" } it cycles to "yes". `:checkhealth cascade` reports the
    -- words that collide across the packs you enabled.
    --
    -- Set to {} to run with only your own `groups`.
    packs = { "en", "de", "dev" },
    -- Your own groups, plus the language-neutral syntax cycles that are not
    -- part of any language. Checked BEFORE the packs, so a group here
    -- overrides whatever a pack says about the same word.
    groups = {
      -- multi-state cycles (wrap around)
      { ".", "/", "\\" },
      -- operator flips: not 'iskeyword' characters, so word_cycle.lua matches
      -- these via a literal-position scan (token.operator_span) rather than
      -- the keyword-span used for the word groups in the packs.
      { "==", "!=" },
      { "&&", "||" },
      { "<", ">" },
      { "+", "-" },
    },
    per_filetype = {},
  },

  -- Renumbering *inside a selection*, independent of filetype and of whatever
  -- precedes the number -- the cases `lists.renumber` structurally can't see,
  -- because `lists.marker.parse` requires the number to be the line's first
  -- token: numbered Markdown headlines (`### 2. iwas`) and inline numbers in
  -- prose, selected mid-line. See cascade.sequence.renumber.
  --   start: "keep" (default) takes the start value from the first hit, like
  --          lists/renumber.lua does; "one" always restarts at 1/a/i.
  --   types: kinds tried, in order, to classify the *first* hit -- which then
  --          locks the kind for the rest of the run. Single letters are read
  --          as `ascii` before `roman` here (a)b)c) is the commoner case); put
  --          "roman" first for i./ii./iii. sequences.
  sequence = {
    enable = true,
    start = "keep",
    types = { "digit", "ascii", "roman" },
  },

  transpose = {
    enable = true,
    features = {
      char = true, -- swap the char (or same-line selection) with its left/right neighbor
      word = true, -- swap the word (or same-line selection) with its left/right neighbor word
    },
  },

  -- `preset = false` binds nothing. Beyond that, each key is an individually
  -- overridable named action, split by where it applies: `globals` for the
  -- keys that work everywhere, `list` for the ones bound inside a buffer whose
  -- filetype matched. `keymaps = { globals = { move_up = "<A-k>" } }` moves
  -- one; `= false` drops one. The feature switches (`lists.features.*`,
  -- `cycle.features.*`, …) still gate their whole group.
  -- See bindings/keymaps.lua for the full set of names.
  keymaps = {
    preset = false,
    globals = {},
    list = {},
  },

  -- Debug logging at cascade's central decision points (detect -> advance ->
  -- fallback): dispatch.try's handler chain, and lists_active()'s gate.
  -- Bridges to lib.nvim.logger (a cached "cascade" instance) when available,
  -- else vim.notify at DEBUG level. False by default -- even the check is a
  -- single cheap boolean read when off.
  debug = false,
}

return DEFAULTS

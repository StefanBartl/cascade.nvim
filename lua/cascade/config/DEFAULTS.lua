---@module 'cascade.config.DEFAULTS'
---@brief Immutable default configuration for cascade.nvim.
---@description
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
      states = { " ", "x" },
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
    },
    filetypes = nil,
    number_fallback = true,
    groups = {
      -- 2-state toggles
      { "true", "false" },
      { "on", "off" },
      { "yes", "no" },
      { "enabled", "disabled" },
      { "enable", "disable" },
      { "active", "inactive" },
      { "visible", "hidden" },
      { "show", "hide" },
      { "accept", "reject" },
      { "include", "exclude" },
      { "open", "closed" },
      { "lock", "unlock" },
      { "locked", "unlocked" },
      { "connected", "disconnected" },
      { "attach", "detach" },
      { "start", "stop" },
      { "pause", "resume" },
      { "mute", "unmute" },
      { "muted", "unmuted" },
      { "up", "down" },
      { "left", "right" },
      { "in", "out" },
      { "asc", "desc" },
      -- multi-state cycles (wrap around)
      { ".", "/", "\\" },
      -- operator flips: not 'iskeyword' characters, so word_cycle.lua matches
      -- these via a literal-position scan (token.operator_span) rather than
      -- the keyword-span used for the word groups above.
      { "==", "!=" },
      { "&&", "||" },
      { "<", ">" },
      { "+", "-" },
    },
    per_filetype = {},
  },

  transpose = {
    enable = true,
    features = {
      char = true, -- swap the char (or same-line selection) with its left/right neighbor
    },
  },

  keymaps = {
    preset = false,
  },

  -- Debug logging at cascade's central decision points (detect -> advance ->
  -- fallback): dispatch.try's handler chain, and lists_active()'s gate.
  -- Bridges to lib.nvim.logger (a cached "cascade" instance) when available,
  -- else vim.notify at DEBUG level. False by default -- even the check is a
  -- single cheap boolean read when off.
  debug = false,
}

return DEFAULTS

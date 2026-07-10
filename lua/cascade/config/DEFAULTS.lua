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
    cycle = { "-", "*", "+", "1.", "a)", "I." },
    forms = { "1.", "1. [ ]", "- [ ]", "-" },
    checkbox = {
      states = { " ", "x" },
    },
    continue = {
      delete_empty = true,
    },
    -- When ordered lists are auto-renumbered.
    --   enable: master switch (false = only manual :CascadeRenumber)
    --   on:     any of "edit" (right after indent/move/continue/...) and "save"
    --           (BufWritePre). A plain boolean is also accepted: true = {"edit"}.
    renumber = {
      enable = true,
      on = { "edit" },
    },
  },

  cycle = {
    enable = true,
    features = {
      word = true, -- cycle the word/boolean under the cursor
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
    },
    per_filetype = {},
  },

  keymaps = {
    preset = false,
  },
}

return DEFAULTS

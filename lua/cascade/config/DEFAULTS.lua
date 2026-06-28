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
    },
    filetypes = { "markdown", "markdown.mdx", "text", "tex", "norg" },
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
    renumber = true,
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

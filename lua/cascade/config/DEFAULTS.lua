---@module 'cascade.config.DEFAULTS'
---@brief Immutable default configuration for cascade.nvim.
---@description
--- Single source of truth for every configurable value. `cascade.config`
--- deep-merges user options on top of this table. Never mutate it at runtime.

---@type CascadeConfig
local DEFAULTS = {
  lists = {
    enable = true,
    filetypes = { "markdown", "markdown.mdx", "text", "tex", "norg" },
    types = { "unordered", "digit" },
    unordered_markers = { "-", "*", "+" },
    cycle = { "-", "*", "+", "1.", "a)", "I." },
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

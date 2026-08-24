---@module 'cascade.integrations.menu'
---@brief Context-aware menu entries for nvzone/menu (soft, opt-in integration).
---@description
--- cascade.nvim does not depend on a menu plugin. It *provides* a list of
--- entries in the shape nvzone/menu expects, built with
--- `lib.nvim.contextmenu`'s helpers, and a host — typically the user's own
--- RightMouse dispatcher — composes them into its own menu for the current
--- buffer, e.g.:
--- >
---   local items = require("cascade.integrations.menu").items()
---   -- prepend/append `items` to your own menu table, then menu.open(composed)
--- <
--- Covers only the "lists" feature-world (the same buffer-local keys
--- `cascade.bindings.keymaps.bind_list_buffer` installs) — cycle/sequence/
--- transpose are global, cursor-position-driven presets that don't compress
--- into discrete "pick an action" menu items, so they're deliberately left
--- out. Entries self-gate on `lists.enable`, the current buffer's filetype
--- being in `lists.filetypes`, and each `lists.features.*` flag — exactly
--- the same gates `bind_list_buffer` applies, so the menu never offers
--- anything the keyboard wouldn't.

local contextmenu = require("lib.nvim.contextmenu")

local M = {}

---@internal
--- Whether `ft` is in `fts` (nil `fts` means "every filetype", matching
--- `cascade.bindings.autocmds`' own `ft_in`).
---@param fts string[]|nil
---@param ft string
---@return boolean
local function ft_in(fts, ft)
  if fts == nil then return true end
  for i = 1, #fts do
    if fts[i] == ft then return true end
  end
  return false
end

--- Build the cascade.nvim (lists) menu entries for `bufnr`.
--- Returns an empty list when lists are disabled, the buffer's filetype
--- isn't configured, or every feature is off, so a host can safely
--- `vim.list_extend` it unconditionally.
---@param bufnr? integer defaults to the current buffer
---@return Lib.ContextMenu.Item[]
function M.items(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local cfg = require("cascade.config").get("lists")
  if not cfg or cfg.enable == false then return {} end
  if not ft_in(cfg.filetypes, vim.bo[bufnr].filetype) then return {} end

  local feat = cfg.features or {}
  local function on(name) return feat[name] ~= false end

  local api = require("cascade")
  local out = {}

  contextmenu.group(
    out,
    contextmenu.entry(on("checkbox"), "  Toggle checkbox", api.toggle_checkbox, "<leader>cx"),
    contextmenu.entry(on("cycle_type"), "  Cycle list marker type", api.cycle_type_next, "<leader>ct"),
    contextmenu.entry(on("cycle_type"), "  Cycle list marker type back", api.cycle_type_prev, "<leader>cT")
  )

  contextmenu.group(
    out,
    contextmenu.entry(true, "  Renumber list", api.renumber, "<leader>cr"),
    contextmenu.entry(on("rotate"), "  Rotate list form", api.rotate_form_next, "<leader>cf"),
    contextmenu.entry(on("sort"), "  Sort list A-Z", api.sort, "<leader>cs"),
    contextmenu.entry(on("reverse"), "  Reverse list order", api.reverse, "<leader>cv")
  )

  contextmenu.group(
    out,
    contextmenu.entry(on("strip"), "  Strip checkboxes", api.strip_checkbox, "<leader>cX")
  )

  return out
end

--- Convenience: the cascade.nvim entries wrapped as a single nested submenu
--- entry, for hosts that prefer a "Cascade ▸" fly-out instead of inline
--- entries. Returns nil when there is nothing to show.
---@param label? string submenu label (default "  Cascade")
---@param bufnr? integer
---@return Lib.ContextMenu.Item|nil
function M.submenu(label, bufnr)
  return contextmenu.submenu(label or "  Cascade", M.items(bufnr))
end

return M

---@module 'cascade.integrations.menu'
---@brief Context-aware menu entries for nvzone/menu (soft, opt-in integration).
---@description
--- cascade.nvim does not depend on a menu plugin. It *provides* a list of
--- entries in the shape nvzone/menu expects, built with
--- `ui.contextmenu`'s helpers, and a host — typically the user's own
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
---
--- `ui.nvim` is optional (docs/installation.md): "Without ui.nvim installed
--- at all, cycle.pick falls back to plain vim.ui.select directly" is the
--- promise for the *other* ui.nvim integration, and this one holds it too
--- (LUA-01) — `entry`/`group`/`submenu` are pure item-table builders with no
--- renderer/nvzone dependency of their own (see ui.nvim's own doc comment:
--- "the item builders ... are unconditional and always available"), so the
--- fallback below reproduces them verbatim instead of erroring. Only these
--- three are used here; `contextmenu.open`/`bind_buffer` (which do need a
--- renderer) are the host's problem, not this module's.
local ok_cm, contextmenu = pcall(require, "ui.contextmenu")
if not ok_cm then
  contextmenu = {
    ---@param available any
    ---@param label string
    ---@param fn function
    ---@param rtxt? string
    ---@param opts? { icon?: string, icon_hl?: string, hl?: string }
    entry = function(available, label, fn, rtxt, opts)
      if not available then
        return nil
      end
      opts = opts or {}
      return {
        name = label,
        rtxt = rtxt,
        cmd = fn,
        icon = opts.icon,
        icon_hl = opts.icon_hl,
        hl = opts.hl,
      }
    end,
    ---@param out table[]
    ---@param ... table|nil
    ---@return boolean added
    group = function(out, ...)
      local n = select("#", ...)
      local compact = {}
      for i = 1, n do
        local item = select(i, ...)
        if item ~= nil then
          compact[#compact + 1] = item
        end
      end

      local heading = nil
      if compact[1] and compact[1].__heading then
        heading = table.remove(compact, 1)
      end

      if #compact == 0 then
        return false
      end
      if #out > 0 and not heading then
        out[#out + 1] = { name = "separator" }
      end
      if heading then
        out[#out + 1] = heading
      end
      for _, item in ipairs(compact) do
        out[#out + 1] = item
      end
      return true
    end,
    ---@param label string
    ---@param items table[]
    ---@param opts? { icon?: string, icon_hl?: string, hl?: string }
    submenu = function(label, items, opts)
      if type(items) ~= "table" or #items == 0 then
        return nil
      end
      opts = opts or {}
      return {
        name = label,
        items = items,
        icon = opts.icon,
        icon_hl = opts.icon_hl,
        hl = opts.hl,
      }
    end,
  }
end

local M = {}

---@internal
--- Whether `ft` is in `fts` (nil `fts` means "every filetype", matching
--- `cascade.bindings.autocmds`' own `ft_in`).
---@param fts string[]|nil
---@param ft string
---@return boolean
local function ft_in(fts, ft)
  if fts == nil then
    return true
  end
  for i = 1, #fts do
    if fts[i] == ft then
      return true
    end
  end
  return false
end

--- Whether a host that asks first (ui.nvim's `ui.menu`) may show this
--- plugin's fly-out: `integrations.ui_menu` is not false and lists are not
--- switched off (`lists.enable`, which gates every entry here). `items()`/
--- `submenu()` themselves stay governed by `lists` alone, so other hosts are
--- unaffected by `ui_menu`.
---@return boolean
function M.enabled()
  local config = require("cascade.config")
  local integrations = config.get("integrations")
  if type(integrations) == "table" and integrations.ui_menu == false then
    return false
  end
  local lists = config.get("lists")
  return not (not lists or lists.enable == false)
end

--- Build the cascade.nvim (lists) menu entries for `bufnr`.
--- Returns an empty list when lists are disabled, the buffer's filetype
--- isn't configured, or every feature is off, so a host can safely
--- `vim.list_extend` it unconditionally.
---@param bufnr? integer defaults to the current buffer
---@return Ui.ContextMenu.Item[]
function M.items(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local cfg = require("cascade.config").get("lists")
  if not cfg or cfg.enable == false then
    return {}
  end
  if not ft_in(cfg.filetypes, vim.bo[bufnr].filetype) then
    return {}
  end

  local feat = cfg.features or {}
  local function on(name)
    return feat[name] ~= false
  end

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

  contextmenu.group(out, contextmenu.entry(on("strip"), "  Strip checkboxes", api.strip_checkbox, "<leader>cX"))

  return out
end

--- Convenience: the cascade.nvim entries wrapped as a single nested submenu
--- entry, for hosts that prefer a "Cascade ▸" fly-out instead of inline
--- entries. Returns nil when there is nothing to show.
---@param label? string submenu label (default "  Cascade")
---@param bufnr? integer
---@return Ui.ContextMenu.Item|nil
function M.submenu(label, bufnr)
  return contextmenu.submenu(label or "  Cascade", M.items(bufnr))
end

return M

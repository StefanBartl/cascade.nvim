---@module 'cascade.config'
---@brief Runtime configuration store for cascade.nvim.
---@description
--- Deep-merges user options over `cascade.config.DEFAULTS` and exposes a single
--- `get(path)` accessor (dot-separated path) so other modules never read a raw
--- options table directly. This preserves fallback semantics and keeps the
--- merged config in one place.

local DEFAULTS = require("cascade.config.DEFAULTS")

---@class CascadeConfigModule
---@field options CascadeConfig
local M = {}

M.options = DEFAULTS

--- Recursively merge `override` into a copy of `base`.
--- Arrays (list-like tables) are replaced wholesale, not concatenated, so a user
--- can fully redefine e.g. `cycle.groups` without inheriting defaults.
---@param base table
---@param override table
---@return table
local function deep_merge(base, override)
  local out = {}
  for k, v in pairs(base) do
    out[k] = v
  end
  for k, v in pairs(override) do
    if type(v) == "table" and type(out[k]) == "table" and not vim.islist(v) then
      out[k] = deep_merge(out[k], v)
    else
      out[k] = v
    end
  end
  return out
end

--- Normalize `lists.renumber`: accept a boolean (back-compat) or a partial table
--- and always end up with `{ enable = boolean, on = string[], blank_break = int }`.
---@param o CascadeConfig
---@return nil
local function normalize(o)
  local lists = o.lists
  if type(lists) ~= "table" then
    return
  end
  local r = lists.renumber
  if type(r) == "boolean" then
    lists.renumber = { enable = r, on = r and { "edit", "save" } or {}, blank_break = 0 }
  elseif type(r) == "table" then
    if r.enable == nil then
      r.enable = true
    end
    if type(r.on) ~= "table" then
      r.on = { "edit", "save" }
    end
    if type(r.blank_break) ~= "number" or r.blank_break < 0 then
      r.blank_break = 0
    end
  else
    lists.renumber = { enable = true, on = { "edit", "save" }, blank_break = 0 }
  end
end

--- Apply user options. Safe to call once from `setup()`.
---@param opts CascadeConfig|nil
---@return nil
function M.setup(opts)
  if type(opts) ~= "table" then
    M.options = deep_merge(DEFAULTS, {})
  else
    M.options = deep_merge(DEFAULTS, opts)
  end
  normalize(M.options)
end

--- Read a value by dot-path, e.g. `get("lists.checkbox.states")`.
---@param path string
---@return any
function M.get(path)
  if type(path) ~= "string" then
    return nil
  end
  local node = M.options
  for key in path:gmatch("[^.]+") do
    if type(node) ~= "table" then
      return nil
    end
    node = node[key]
  end
  return node
end

return M

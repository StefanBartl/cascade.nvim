---@module 'cascade.config'
--- Runtime configuration store for cascade.nvim.
---
--- Deep-merges user options over `cascade.config.DEFAULTS` and exposes a single
--- `get(path)` accessor (dot-separated path) so other modules never read a raw
--- options table directly. This preserves fallback semantics and keeps the
--- merged config in one place.
---
--- The merge and the dot-path lookup are `lib.lua.config`'s: this module used
--- to carry its own byte-identical copies of both (spotlight.nvim had the
--- other copy) — see that lib module's doc comment for why the merge isn't
--- `lib.lua.tables.core.deep_merge`.

local DEFAULTS = require("cascade.config.DEFAULTS")
local lib_config = require("lib.lua.config")

---@class CascadeConfigModule
---@field options CascadeConfig
local M = {}

M.options = DEFAULTS

---@internal
--- Normalize `sequence`: guard the two values `cascade.sequence.renumber` reads
--- without re-checking (`start` is compared against "one", `types` is iterated),
--- so a typo degrades to the documented default instead of silently changing
--- behaviour or erroring mid-scan.
---@param o CascadeConfig
---@return nil
local function normalize_sequence(o)
  local seq = o.sequence
  if type(seq) ~= "table" then
    o.sequence = { enable = true, start = "keep", types = { "digit", "ascii", "roman" } }
    return
  end
  if seq.enable == nil then
    seq.enable = true
  end
  if seq.start ~= "one" then
    seq.start = "keep"
  end
  if type(seq.types) ~= "table" or #seq.types == 0 then
    seq.types = { "digit", "ascii", "roman" }
  end
end

---@internal
--- Normalize `lists.renumber`: accept a boolean (back-compat) or a partial table
--- and always end up with `{ enable = boolean, on = string[], blank_break = int }`.
---@param o CascadeConfig
---@return nil
local function normalize(o)
  normalize_sequence(o)
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
    M.options = lib_config.deep_merge(DEFAULTS, {})
  else
    M.options = lib_config.deep_merge(DEFAULTS, opts)
  end
  normalize(M.options)
end

--- Read a value by dot-path, e.g. `get("lists.checkbox.states")`.
---@param path string
---@return any
function M.get(path)
  return lib_config.get(M.options, path)
end

return M

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
--- What the last `setup()` had to reject or degrade, one human-readable line
--- each, for `:checkhealth` (ERR-50/ERR-22). Empty when everything was
--- accepted as given.
---@type string[]
local _issues = {}

---@internal
--- Top-level keys `setup()` accepts and, for the fixed-schema tables among
--- them, their own direct keys (one level, not recursive -- see
--- `sanitize()`). `true` means "any key goes": `keymaps` mixes a fixed
--- `preset` switch with two action-name-keyed maps (`globals`, `list`), so
--- it is not checked at all.
---@type table<string, true|table<string, true>>
local KNOWN = {
  lists = {
    enable = true,
    features = true,
    filetypes = true,
    types = true,
    unordered_markers = true,
    per_filetype_patterns = true,
    cycle = true,
    forms = true,
    checkbox = true,
    continue = true,
    renumber = true,
    precision = true,
    precision_nodes = true,
  },
  cycle = {
    enable = true,
    features = true,
    filetypes = true,
    number_fallback = true,
    packs = true,
    groups = true,
    per_filetype = true,
  },
  sequence = { enable = true, start = true, types = true },
  transpose = { enable = true, features = true },
  strings = {
    enable = true,
    features = true,
    template_filetypes = true,
    fstring_filetypes = true,
    lua_format_filetypes = true,
    max_characters = true,
    quote = true,
    on = true,
  },
  keymaps = true,
  debug = true,
}

---@internal
--- `key` with the nearest known one as a hint when there is a plausible one
--- (edit distance <= 3).
---@param key any
---@param known table<string, any>
---@param prefix string
---@return string
local function describe_unknown(key, known, prefix)
  local levenshtein = require("lib.lua.strings.distance").levenshtein
  local name = tostring(key)
  local best, best_distance = nil, nil
  for candidate in pairs(known) do
    local d = levenshtein(name, candidate)
    if d <= 3 and (best_distance == nil or d < best_distance) then
      best, best_distance = candidate, d
    end
  end
  if best then
    return ("unknown option '%s%s' (did you mean '%s%s'?)"):format(prefix, name, prefix, best)
  end
  return ("unknown option '%s%s'"):format(prefix, name)
end

---@internal
--- Drop what cannot be merged, and say so, before the merge (ERR-50): a
--- misspelled key would otherwise land in the active config as a dead field
--- with the default still silently in force, and a non-table value for an
--- option table (`lists = false`) would replace the whole table and throw on
--- the first nested read instead of falling back to the default.
---@param user_opts table
---@return table clean
---@return string[] issues
local function sanitize(user_opts)
  local clean, issues = {}, {}
  for key, value in pairs(user_opts) do
    local known = KNOWN[key]
    if known == nil then
      issues[#issues + 1] = describe_unknown(key, KNOWN, "")
    elseif type(DEFAULTS[key]) == "table" and type(value) ~= "table" then
      issues[#issues + 1] = ("option '%s' must be a table, got %s -- using the default"):format(key, type(value))
    elseif type(known) == "table" then
      local nested = {}
      for sub_key, sub_value in pairs(value) do
        if known[sub_key] then
          nested[sub_key] = sub_value
        else
          issues[#issues + 1] = describe_unknown(sub_key, known, key .. ".")
        end
      end
      -- An empty table is indistinguishable from an array to the merge
      -- below (`lib.lua.config.deep_merge`'s array check is vacuously true
      -- on `{}`), which replaces the WHOLE key wholesale instead of merging
      -- -- if every sub-key the user gave was rejected above (e.g. a single
      -- typo'd sub-key), that would wipe every *other* default under `key`
      -- instead of leaving them alone. Only set the key at all when there is
      -- a real override left to apply.
      if next(nested) ~= nil then
        clean[key] = nested
      end
    else
      clean[key] = value
    end
  end
  table.sort(issues)
  return clean, issues
end

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
--- Normalize `strings`: the autocmd layer iterates `on` and the converters
--- read `max_characters`/`quote` without re-checking, so a wrong type
--- degrades to the shipped default instead of erroring on every keystroke.
---@param o CascadeConfig
---@return nil
local function normalize_strings(o)
  local s = o.strings
  if type(s) ~= "table" then
    o.strings = lib_config.deep_merge(DEFAULTS.strings, {})
    return
  end
  if s.enable == nil then
    s.enable = true
  end
  if type(s.features) ~= "table" then
    s.features = lib_config.deep_merge(DEFAULTS.strings.features, {})
  end
  if type(s.on) ~= "table" then
    s.on = { "InsertLeave", "TextChanged" }
  end
  if type(s.max_characters) ~= "number" or s.max_characters < 1 then
    s.max_characters = 200
  end
  if s.quote ~= "'" then
    s.quote = '"'
  end
end

---@internal
--- Normalize `lists.filetypes`, `lists.checkbox` and `lists.continue`: several
--- call sites (health.lua's `table.concat`, format.lua/marker.lua/continue.lua's
--- `opts.continue.*`/`opts.checkbox.*`) index these unconditionally, assuming
--- the shape `deep_merge` does not actually guarantee -- a wrong type here
--- degrades to the default instead of throwing the first time one of those
--- runs (or, for `:checkhealth` itself, on the very check meant to explain it).
--- `cycle.filetypes` gets the same treatment for `lists.filetypes`, except its
--- default is legitimately `nil` ("every filetype"), not a table.
---@param o CascadeConfig
---@param issues string[]
---@return nil
local function normalize_lists_shape(o, issues)
  local lists = o.lists
  if type(lists) == "table" then
    if type(lists.filetypes) ~= "table" then
      issues[#issues + 1] = ("lists.filetypes must be a table of filetypes, got %s -- using the default"):format(
        type(lists.filetypes)
      )
      lists.filetypes = vim.deepcopy(DEFAULTS.lists.filetypes)
    end
    if type(lists.checkbox) ~= "table" then
      issues[#issues + 1] = ("lists.checkbox must be a table, got %s -- using the default"):format(type(lists.checkbox))
      lists.checkbox = vim.deepcopy(DEFAULTS.lists.checkbox)
    end
    if type(lists.continue) ~= "table" then
      issues[#issues + 1] = ("lists.continue must be a table, got %s -- using the default"):format(type(lists.continue))
      lists.continue = vim.deepcopy(DEFAULTS.lists.continue)
    end
  end

  local cyc = o.cycle
  if type(cyc) == "table" and cyc.filetypes ~= nil and type(cyc.filetypes) ~= "table" then
    issues[#issues + 1] = ("cycle.filetypes must be nil or a table of filetypes, got %s -- using nil (every filetype)"):format(
      type(cyc.filetypes)
    )
    cyc.filetypes = nil
  end
end

---@internal
--- Normalize `lists.renumber`: accept a boolean (back-compat) or a partial table
--- and always end up with `{ enable = boolean, on = string[], blank_break = int }`.
---@param o CascadeConfig
---@param issues string[]
---@return nil
local function normalize(o, issues)
  normalize_sequence(o)
  normalize_strings(o)
  normalize_lists_shape(o, issues)
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
---
--- Unknown keys and mistyped option values are rejected/degraded and
--- reported once here and again by `:checkhealth cascade` (see `M.issues()`);
--- they never reach the merge.
---@param opts CascadeConfig|nil
---@return nil
function M.setup(opts)
  local clean, sanitize_issues
  if type(opts) ~= "table" then
    clean, sanitize_issues = {}, {}
  else
    clean, sanitize_issues = sanitize(opts)
  end
  M.options = lib_config.deep_merge(DEFAULTS, clean)

  local issues = sanitize_issues
  normalize(M.options, issues)
  _issues = issues
  if #issues > 0 then
    require("cascade.util.lib").notify("ignored/degraded config: " .. table.concat(issues, "; "), vim.log.levels.WARN)
  end

  -- Pack resolution is cached per pack list (it runs on every keypress); a
  -- re-setup() with different `cycle.packs` has to invalidate it.
  pcall(function()
    require("cascade.cycle.packs").invalidate()
  end)
end

--- Read a value by dot-path, e.g. `get("lists.checkbox.states")`.
---@param path string
---@return any
function M.get(path)
  return lib_config.get(M.options, path)
end

--- What the last `setup()` ignored or degraded: unknown keys and option
--- values of the wrong type, one human-readable line each. Empty when
--- everything was accepted as given. For `:checkhealth cascade`.
---@return string[]
function M.issues()
  return vim.list_extend({}, _issues)
end

return M

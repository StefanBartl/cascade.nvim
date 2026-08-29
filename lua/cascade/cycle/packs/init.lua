---@module 'cascade.cycle.packs'
--- Named bundles of cycle groups ("packs"), selected via `cycle.packs`.
---
--- A pack is just a `string[][]` of groups, identical in shape to
--- `cycle.groups` -- the split exists so a whole language can be switched on
--- or off by name instead of being pasted into the config. Language packs
--- carry that language's boolean/state vocabulary; `dev` carries the
--- language-neutral developer cycles (environments, levels, HTTP verbs, ...).
---
--- Resolution is cached per pack list: `groups_for` runs on every keypress,
--- and the packs only change when `setup()` does.

local M = {}

--- Every pack that ships with cascade, in the order `:checkhealth` lists them.
---@type string[]
M.KNOWN = { "en", "de", "es", "fr", "it", "pt", "nl", "ru", "dev" }

---@type table<string, boolean>
local known_set = {}
for i = 1, #M.KNOWN do
  known_set[M.KNOWN[i]] = true
end

---@type table<string, string[][]>
local cache = {}

---@type table<string, boolean>
local warned = {}

--- Resolve `names` to the concatenated groups of those packs, in the given
--- order (which is also their precedence -- `word_cycle` takes the first
--- group a word appears in). Unknown names are skipped with a single warning
--- each, so a typo degrades to "that pack is missing" rather than an error on
--- every keypress.
---@param names string[]|nil # `cycle.packs`; nil or empty resolves to `{}`.
---@return string[][]
function M.resolve(names)
  if type(names) ~= "table" or #names == 0 then
    return {}
  end

  local key = table.concat(names, ",")
  local hit = cache[key]
  if hit then
    return hit
  end

  local out = {}
  local n = 0
  for i = 1, #names do
    local name = names[i]
    if known_set[name] then
      local ok, groups = pcall(require, "cascade.cycle.packs." .. name)
      if ok and type(groups) == "table" then
        for j = 1, #groups do
          n = n + 1
          out[n] = groups[j]
        end
      end
    elseif not warned[name] then
      warned[name] = true
      require("cascade.util.lib").notify(
        ("unknown cycle pack %s (known: %s)"):format(vim.inspect(name), table.concat(M.KNOWN, ", ")),
        vim.log.levels.WARN
      )
    end
  end

  cache[key] = out
  return out
end

--- Drop the resolution cache. Called from `config.setup` so a re-`setup()`
--- with different packs takes effect without restarting Neovim.
---@return nil
function M.invalidate()
  cache = {}
  warned = {}
end

---@internal
--- Whether two groups hold the same entries in the same order.
---@param a string[]
---@param b string[]
---@return boolean
local function same_group(a, b)
  if #a ~= #b then
    return false
  end
  for i = 1, #a do
    if a[i] ~= b[i] then
      return false
    end
  end
  return true
end

--- Report words that appear in more than one group of `groups`.
---
--- Only the *first* group containing a word is ever reached (see
--- `word_cycle.find_group`), so a word in two differing groups silently makes
--- the later one unreachable -- likely when several language packs are on at
--- once (`no` is both English and Spanish). Groups that are outright
--- identical (`links`/`rechts` in both `de` and `nl`) are not reported: the
--- duplicate is redundant but changes nothing.
---@param groups string[][]
---@return { word: string, winner: string[], shadowed: string[] }[]
function M.conflicts(groups)
  local first = {} ---@type table<string, string[]>
  local out = {}
  local seen = {} ---@type table<string, boolean>

  for i = 1, #groups do
    local grp = groups[i]
    for j = 1, #grp do
      local word = tostring(grp[j]):lower()
      local owner = first[word]
      if owner == nil then
        first[word] = grp
      elseif owner ~= grp and not same_group(owner, grp) and not seen[word] then
        seen[word] = true
        out[#out + 1] = { word = word, winner = owner, shadowed = grp }
      end
    end
  end
  return out
end

return M

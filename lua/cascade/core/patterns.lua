---@module 'cascade.core.patterns'
---@brief Memoized Lua-pattern fragments for marker detection.
---@description
--- Marker parsing only needs plain line scans (no Treesitter). The few derived
--- pattern fragments (e.g. the unordered char-class) depend solely on config and
--- are stable for a session, so we memoize them by a cheap string key to avoid
--- rebuilding on every keystroke.

local M = {}

---@type table<string, string>
local cache = {}

--- Escape a single character for safe use inside a Lua pattern char-class.
---@param c string
---@return string
local function esc(c)
  return (c:gsub("(%W)", "%%%1"))
end

--- Build (and memoize) a char-class matching any configured unordered marker,
--- e.g. { "-", "*", "+" } -> "[%-%*%+]".
---@param markers string[]
---@return string
function M.unordered_class(markers)
  local key = table.concat(markers, "\0")
  local cached = cache[key]
  if cached then
    return cached
  end
  local parts = {}
  for i = 1, #markers do
    parts[i] = esc(markers[i])
  end
  local cls = "[" .. table.concat(parts) .. "]"
  cache[key] = cls
  return cls
end

return M

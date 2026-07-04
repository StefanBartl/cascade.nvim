---@module 'cascade.lists.roman'
---@brief Pure Roman-numeral <-> integer conversion (1..3999).
---@description
--- No side effects, no Neovim API: trivially unit-testable. `to_int` validates
--- by round-trip so malformed input like "IIII" or "VX" is rejected, which lets
--- marker detection rely on it to disambiguate real Roman markers from words.

local M = {}

---@type [integer, string][]
local STEPS = {
  { 1000, "M" },
  { 900, "CM" },
  { 500, "D" },
  { 400, "CD" },
  { 100, "C" },
  { 90, "XC" },
  { 50, "L" },
  { 40, "XL" },
  { 10, "X" },
  { 9, "IX" },
  { 5, "V" },
  { 4, "IV" },
  { 1, "I" },
}

---@type table<string, integer>
local VALUE = { I = 1, V = 5, X = 10, L = 50, C = 100, D = 500, M = 1000 }

--- Convert an integer to an uppercase Roman numeral.
---@param n integer
---@return string|nil # nil if out of the representable range.
function M.to_roman(n)
  if type(n) ~= "number" or n < 1 or n > 3999 then
    return nil
  end
  local rem = math.floor(n)
  local out, k = {}, 0
  for i = 1, #STEPS do
    local v, sym = STEPS[i][1], STEPS[i][2]
    while rem >= v do
      k = k + 1
      out[k] = sym
      rem = rem - v
    end
  end
  return table.concat(out)
end

--- Convert a Roman numeral (any case) to an integer, or nil if invalid.
---@param s string
---@return integer|nil
function M.to_int(s)
  if type(s) ~= "string" or s == "" then
    return nil
  end
  local up = s:upper()
  if not up:match("^[MDCLXVI]+$") then
    return nil
  end
  local total = 0
  for i = 1, #up do
    local cur = VALUE[up:sub(i, i)]
    local nxt = VALUE[up:sub(i + 1, i + 1)] or 0
    if cur < nxt then
      total = total - cur
    else
      total = total + cur
    end
  end
  -- Reject non-canonical forms (e.g. "IIII", "IC") by round-trip.
  if M.to_roman(total) ~= up then
    return nil
  end
  return total
end

return M

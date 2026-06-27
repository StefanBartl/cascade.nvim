---@module 'cascade.lists.alpha'
---@brief Pure bijective base-26 alphabetic ordinal <-> integer conversion.
---@description
--- Maps a -> 1, z -> 26, aa -> 27, ... (spreadsheet-style). No side effects, no
--- Neovim API. Case is the caller's concern; conversion always works lowercase.

local M = {}

--- Convert an alphabetic ordinal (any case) to an integer, or nil if invalid.
---@param s string
---@return integer|nil
function M.to_int(s)
  if type(s) ~= "string" or not s:match("^%a+$") then
    return nil
  end
  local low = s:lower()
  local n = 0
  for i = 1, #low do
    n = n * 26 + (low:byte(i) - 96)
  end
  return n
end

--- Convert a positive integer to its lowercase alphabetic ordinal.
---@param n integer
---@return string|nil
function M.to_alpha(n)
  if type(n) ~= "number" or n < 1 then
    return nil
  end
  n = math.floor(n)
  local rev, k = {}, 0
  while n > 0 do
    local r = (n - 1) % 26
    k = k + 1
    rev[k] = string.char(97 + r)
    n = math.floor((n - 1) / 26)
  end
  -- Built least-significant first; reverse into order.
  local out = {}
  for i = k, 1, -1 do
    out[k - i + 1] = rev[i]
  end
  return table.concat(out)
end

return M

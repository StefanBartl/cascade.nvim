---@module 'cascade.lists.alpha'
---@brief Pure bijective base-26 alphabetic ordinal <-> integer conversion.
---@description
--- Maps a -> 1, z -> 26, aa -> 27, ... (spreadsheet-style). No side effects, no
--- Neovim API. Case is the caller's concern; conversion always works lowercase.
--- Delegates to the soft lib.nvim bridge (util/lib.lua): lib.lua.numeral.alpha
--- when available, else an equivalent standalone fallback.

local M = {}

--- Convert an alphabetic ordinal (any case) to an integer, or nil if invalid.
---@param s string
---@return integer|nil
function M.to_int(s)
  return require("cascade.util.lib").alpha_to_int(s)
end

--- Convert a positive integer to its lowercase alphabetic ordinal.
---@param n integer
---@return string|nil
function M.to_alpha(n)
  return require("cascade.util.lib").alpha_to_alpha(n)
end

return M

---@module 'cascade.lists.roman'
---@brief Pure Roman-numeral <-> integer conversion (1..3999).
---@description
--- No side effects, no Neovim API: trivially unit-testable. `to_int` validates
--- by round-trip so malformed input like "IIII" or "VX" is rejected, which lets
--- marker detection rely on it to disambiguate real Roman markers from words.
--- Delegates to the soft lib.nvim bridge (util/lib.lua): lib.lua.numeral.roman
--- when available, else an equivalent standalone fallback.

local M = {}

--- Convert an integer to an uppercase Roman numeral.
---@param n integer
---@return string|nil # nil if out of the representable range.
function M.to_roman(n)
  return require("cascade.util.lib").roman_to_roman(n)
end

--- Convert a Roman numeral (any case) to an integer, or nil if invalid.
---@param s string
---@return integer|nil
function M.to_int(s)
  return require("cascade.util.lib").roman_to_int(s)
end

return M

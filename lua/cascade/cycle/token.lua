---@module 'cascade.cycle.token'
---@brief Cursor-token extraction, numeric detection and case-shape helpers.
---@description
--- Pure-ish helpers for the word-cycle feature, ported from the original
--- `ctrl_cycle` mapping. `span` respects 'iskeyword' to find the token under the
--- cursor; `case_shape`/`apply_shape` preserve the user's capitalization when a
--- token is replaced.

local M = {}

--- Find the keyword span under the cursor (0-based byte columns).
---@param line string
---@param col0 integer # 0-based cursor byte column.
---@return integer|nil s, integer|nil e, string|nil text
function M.span(line, col0)
  local pat = [[\k\+]]
  local start_at = 0
  while true do
    local mt = vim.fn.matchstrpos(line, pat, start_at) -- { match, start, end }
    local text, s, e = mt[1], mt[2], mt[3]
    if s == -1 then
      return nil, nil, nil
    end
    if col0 >= s and col0 < e then
      return s, e, text
    end
    start_at = e
  end
end

--- Whether a token looks like an int, strict float, or hex literal.
---@param s string|nil
---@return boolean
function M.is_numeric(s)
  if not s or s == "" then
    return false
  end
  if s:match("^[-+]?%d+$") then
    return true
  end
  if s:match("^[-+]?%d+%.%d+$") then
    return true
  end
  if s:match("^0[xX][%da-fA-F]+$") then
    return true
  end
  return false
end

---@alias CascadeCaseShape "lower"|"upper"|"capital"|"mixed"

--- Classify the capitalization of a token.
---@param s string
---@return CascadeCaseShape
function M.case_shape(s)
  if s == "" then
    return "lower"
  end
  local first, rest = s:sub(1, 1), s:sub(2)
  if s == s:lower() then
    return "lower"
  end
  if s == s:upper() then
    return "upper"
  end
  if first == first:upper() and rest == rest:lower() then
    return "capital"
  end
  return "mixed"
end

--- Apply a case shape to a replacement token.
---@param repl string
---@param shape CascadeCaseShape
---@return string
function M.apply_shape(repl, shape)
  if shape == "upper" then
    return repl:upper()
  elseif shape == "capital" then
    return repl:sub(1, 1):upper() .. repl:sub(2):lower()
  elseif shape == "mixed" then
    return repl
  end
  return repl:lower()
end

return M

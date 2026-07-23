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

--- Find an operator-style group entry (e.g. `"=="`, `"&&"`, `"<"`) touching
--- the cursor, via a literal-position scan rather than `span`'s keyword scan
--- -- operator characters aren't `'iskeyword'`, so `\k\+` never sees them.
--- Only entries that aren't plain word characters are considered, so this
--- never shadows the word groups. Prefers the longest match at the cursor
--- (e.g. `"!="` over a hypothetical single-char `"="` entry).
---@param line string
---@param col0 integer # 0-based cursor byte column.
---@param groups string[][]
---@return integer|nil s0, integer|nil e0, string|nil text # 0-based half-open span [s0, e0).
function M.operator_span(line, col0, groups)
  local best_s, best_e, best_text
  for i = 1, #groups do
    local grp = groups[i]
    for j = 1, #grp do
      local entry = grp[j]
      if entry ~= "" and not entry:match("^%w+$") then
        local len = #entry
        for p = math.max(0, col0 - len + 1), col0 do
          if p + len <= #line and line:sub(p + 1, p + len) == entry then
            if not best_text or len > #best_text then
              best_s, best_e, best_text = p, p + len, entry
            end
          end
        end
      end
    end
  end
  return best_s, best_e, best_text
end

---@alias CascadeCaseShape "lower"|"upper"|"capital"|"mixed"

--- Classify the capitalization of a token. Delegates to the soft
--- lib.nvim bridge (util/lib.lua): lib.lua.strings.case.case_shape when
--- available, else an equivalent standalone fallback.
---@param s string
---@return CascadeCaseShape
function M.case_shape(s)
  return require("cascade.util.lib").case_shape(s)
end

--- Apply a case shape to a replacement token. Delegates to the soft
--- lib.nvim bridge (util/lib.lua): lib.lua.strings.case.apply_shape when
--- available, else an equivalent standalone fallback.
---@param repl string
---@param shape CascadeCaseShape
---@return string
function M.apply_shape(repl, shape)
  return require("cascade.util.lib").apply_shape(repl, shape)
end

return M

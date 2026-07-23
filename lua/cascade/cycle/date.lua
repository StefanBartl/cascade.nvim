---@module 'cascade.cycle.date'
---@brief Increment/decrement the year/month/day segment of an ISO date
--- (`YYYY-MM-DD`) under the cursor.
---@description
--- Vim's native `<C-a>`/`<C-x>` only sees the numeric island touching the
--- cursor -- e.g. just `"31"` in `"2024-01-31"` -- so incrementing the last
--- day of a month produces an invalid date (`"32"`) instead of rolling over
--- into the next month. This finds the full date containing the cursor,
--- works out which segment (year/month/day) the cursor sits on, and lets
--- `os.time`/`os.date` normalize the result (leap years, month lengths, ...)
--- instead of hand-rolling calendar arithmetic.

local M = {}

local PATTERN = "%d%d%d%d%-%d%d%-%d%d"

--- Find the ISO date touching `col0` in `line`, if any.
---@param line string
---@param col0 integer # 0-based cursor byte column.
---@return integer|nil s0, integer|nil e0, string|nil text # 0-based half-open span [s0, e0).
function M.span(line, col0)
  local start_at = 1
  while true do
    local s, e = line:find(PATTERN, start_at)
    if not s then
      return nil, nil, nil
    end
    local s0, e0 = s - 1, e -- string.find is 1-based inclusive; e is already the exclusive 0-based end.
    if col0 >= s0 and col0 < e0 then
      return s0, e0, line:sub(s, e)
    end
    if col0 < e0 then
      return nil, nil, nil -- past the cursor already; no earlier match can reach it either.
    end
    start_at = e + 1
  end
end

--- Which segment the cursor is in, given the date starts at `s0`.
---@param col0 integer
---@param s0 integer
---@return "year"|"month"|"day"
local function segment_at(col0, s0)
  local off = col0 - s0
  if off <= 3 then
    return "year"
  elseif off <= 6 then
    return "month"
  end
  return "day"
end

--- Step the year/month/day segment under `col0` by `dir`, normalized through
--- `os.time`/`os.date` (e.g. day 31 of a 30-day month rolls into the next
--- month; Feb 29 rolls into March in a non-leap target year).
---@param line string
---@param col0 integer
---@param dir integer # 1 = +1, -1 = -1.
---@return integer|nil s0, integer|nil e0, string|nil replacement
function M.step(line, col0, dir)
  local s0, e0, text = M.span(line, col0)
  if not s0 then
    return nil, nil, nil
  end
  ---@cast e0 integer
  ---@cast text string
  local y, mo, d = text:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
  if not y then
    return nil, nil, nil
  end
  -- Noon avoids DST-transition edge cases shifting the calendar day.
  local t = { year = tonumber(y), month = tonumber(mo), day = tonumber(d), hour = 12 }
  local seg = segment_at(col0, s0)
  t[seg] = t[seg] + dir
  local norm = os.date("*t", os.time(t))
  ---@cast norm osdate
  local repl = ("%04d-%02d-%02d"):format(norm.year, norm.month, norm.day)
  return s0, e0, repl
end

return M

---@module 'cascade.cycle.letter'
--- Cycle a single alphabetic letter under the cursor through the alphabet
--- (`a -> b -> ... -> z -> a`, `A -> B -> ... -> Z -> A`), wrapping at the
--- boundary and preserving whichever case the letter already had.
---
--- Scoped to a *single*-character token deliberately: `token.span` returns
--- the whole keyword under the cursor (`\k\+`), so a multi-letter word like
--- "cat" never reaches here — only a lone letter does. That keeps this from
--- fighting configured `cycle.groups` entries (checked first) or clobbering
--- ordinary word text.

local M = {}

--- Step a single-letter `text` by `dir` steps, wrapping within its own case
--- (lower stays lower, upper stays upper). `dir` may be any integer (used as
--- a step count, e.g. `count * -1`), not just +-1.
---@param text string
---@param dir integer
---@return string|nil # nil if `text` isn't exactly one a-z/A-Z letter.
function M.step(text, dir)
  if not text or #text ~= 1 then
    return nil
  end
  local byte = text:byte()
  local base
  if byte >= 97 and byte <= 122 then
    base = 97 -- "a"
  elseif byte >= 65 and byte <= 90 then
    base = 65 -- "A"
  else
    return nil
  end
  local idx = (byte - base + dir) % 26
  return string.char(base + idx)
end

return M

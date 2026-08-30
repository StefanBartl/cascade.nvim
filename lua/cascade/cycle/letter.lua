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
---
--- `step_at` is the deliberate way past that scoping: it reads one byte at
--- the cursor column and ignores word boundaries entirely, so the "a" inside
--- "cat" is reachable too. It is bound to its own keys (`<C-M-y>`/`<C-M-x>`)
--- rather than folded into the `<C-y>` chain, because "step whatever
--- character I am sitting on" is a different intent from "cycle this token",
--- and silently doing it inside words would make `<C-y>` unpredictable on
--- every unknown word.

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

--- Step the single character at `col0` through the alphabet, whatever it sits
--- inside. Unlike `step` fed from `token.span`, this never looks at word
--- boundaries: the cursor column *is* the span, so a letter in the middle of
--- a word cycles like a lone one.
---@param line string
---@param col0 integer # 0-based cursor byte column.
---@param dir integer # Step count (may be any integer, e.g. `count * -1`).
---@return integer|nil s, integer|nil e, string|nil repl # 0-based half-open span [s, e).
function M.step_at(line, col0, dir)
  if type(line) ~= "string" or type(col0) ~= "number" then
    return nil, nil, nil
  end
  if col0 < 0 or col0 >= #line then
    return nil, nil, nil
  end
  local repl = M.step(line:sub(col0 + 1, col0 + 1), dir)
  if not repl then
    return nil, nil, nil
  end
  return col0, col0 + 1, repl
end

return M

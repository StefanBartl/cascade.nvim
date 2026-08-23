---@module 'cascade.sequence.renumber'
--- Renumber the ordinal tokens inside a *selection*, whatever precedes them.
---
--- The list domain's `lists/renumber.lua` can only re-sequence real list items:
--- `lists.marker.parse` requires the number to be the very first token of the
--- line. This module covers the two cases that leaves out — a Markdown
--- headline with an embedded number (`### 2. iwas`), and plain inline numbers
--- in prose (`... nur als 5. beispiel ...`), possibly selected mid-line.
---
--- Both are structurally the same operation: scan the selected text for an
--- ordinal token in order of appearance and rewrite the hits sequentially,
--- independent of filetype and of whatever sits in front of the number. So
--- this is its own domain (like `cycle`/`transpose`), not an extension of the
--- list renumberer.
---
--- Everything here except `range`/`span` is pure: `rewrite` takes a string plus
--- a carry-over state table and returns a new string, so it is trivially
--- testable and can walk a multi-line selection line by line while keeping one
--- running counter.

local roman = require("cascade.lists.roman")
local alpha = require("cascade.lists.alpha")

local M = {}

--- Kinds tried, in order, when the first hit still has to establish the
--- sequence's kind. Mirrors `sequence.types`' default; used as the fallback
--- when that option is empty or malformed.
M.DEFAULT_TYPES = { "digit", "ascii", "roman" }

---@internal
--- Integer value of `tok` read as `kind`, or nil if it isn't that kind.
--- `ascii` is deliberately single-letter only (`a`..`z`), matching
--- `lists/marker.lua`; multi-letter alphabetic tokens are only ever read as
--- Roman numerals, and `roman.to_int` validates by round-trip, so a word like
--- "so" is rejected rather than silently parsed.
---@param kind CascadeSequenceKind
---@param tok string
---@return integer|nil
local function value_of(kind, tok)
  if kind == "digit" then
    if tok:match("^%d+$") then
      return tonumber(tok)
    end
  elseif kind == "ascii" then
    if tok:match("^%a$") then
      return alpha.to_int(tok)
    end
  elseif kind == "roman" then
    if tok:match("^%a+$") then
      return roman.to_int(tok)
    end
  end
  return nil
end

---@internal
--- Render `value` as `kind`, borrowing `ref`'s capitalization (markers are
--- single-script tokens, so lower/UPPER is the whole story).
---@param kind CascadeSequenceKind
---@param value integer
---@param ref string # the token being replaced.
---@return string|nil # nil when `value` is outside the kind's range.
local function render(kind, value, ref)
  if kind == "digit" then
    return tostring(value)
  end
  local out = (kind == "ascii") and alpha.to_alpha(value) or roman.to_roman(value)
  if not out then
    return nil
  end
  if ref == ref:upper() and ref ~= ref:lower() then
    return out:upper()
  end
  return out:lower()
end

---@internal
--- Next ordinal token in `text` at or after byte index `init` (1-based).
---
--- A candidate is an alphanumeric run followed by `.` or `)`. Two boundary
--- rules keep this out of ordinary prose: the run is matched greedily, so the
--- "1" in `v1.2` is never seen on its own, and the delimiter must be followed
--- by whitespace or end-of-text, so decimals (`3.14`) and abbreviations
--- (`e.g.`) don't qualify.
---
--- `kind_lock` is the kind the sequence already committed to (nil for the
--- first hit): once the first token has decided whether this run is digits,
--- letters or Roman numerals, tokens of the *other* kinds are skipped rather
--- than folded into the same sequence. That is what keeps a selection of
--- numbered items from also rewriting an `a)` that happens to sit in the text.
---@param text string
---@param init integer
---@param types CascadeSequenceKind[]
---@param kind_lock CascadeSequenceKind|nil
---@return integer|nil s, integer? e, CascadeSequenceKind? kind, integer? value, string? tok, string? delim
local function next_token(text, init, types, kind_lock)
  local pos = init
  while pos <= #text do
    local s, e, tok, delim = text:find("(%w+)([%.%)])", pos)
    if not s then
      return nil
    end
    local after = text:sub(e + 1, e + 1)
    if after == "" or after:match("^%s$") then
      if kind_lock then
        local v = value_of(kind_lock, tok)
        if v then
          return s, e, kind_lock, v, tok, delim
        end
      else
        for i = 1, #types do
          local v = value_of(types[i], tok)
          if v then
            return s, e, types[i], v, tok, delim
          end
        end
      end
    end
    pos = e + 1
  end
  return nil
end

---@internal
--- The effective kind list for `opts`, falling back to `M.DEFAULT_TYPES`.
---@param opts CascadeSequenceOpts
---@return CascadeSequenceKind[]
local function kinds(opts)
  local types = opts and opts.types
  if type(types) ~= "table" or #types == 0 then
    return M.DEFAULT_TYPES
  end
  return types
end

--- Rewrite every ordinal token in `text` sequentially, carrying the counter
--- (and the committed kind) through `state` so several lines of one selection
--- share a single sequence.
---
--- The delimiter is kept per hit rather than unified on the first one: mixed
--- `.`/`)` styles in the selected text stay exactly as they were, only the
--- number itself is replaced. A token whose new value can't be rendered
--- (a Roman numeral past 3999) is left untouched and does not consume a step.
---@param text string
---@param opts CascadeSequenceOpts
---@param state CascadeSequenceState # mutated in place; pass a fresh `{}` to start a sequence.
---@return string new_text, integer count # `count` = tokens rewritten (0 means `new_text == text`).
function M.rewrite(text, opts, state)
  local types = kinds(opts)
  local out, n, pos, count = {}, 0, 1, 0

  while true do
    local s, e, kind, value, tok, delim = next_token(text, pos, types, state.kind)
    if not s then
      break
    end
    ---@cast e integer
    ---@cast kind CascadeSequenceKind
    ---@cast value integer
    ---@cast tok string
    ---@cast delim string

    if state.next == nil then
      state.kind = kind
      state.next = (opts.start == "one") and 1 or value
    end

    local repl = render(kind, state.next, tok)
    n = n + 1
    out[n] = text:sub(pos, s - 1)
    n = n + 1
    if repl then
      out[n] = repl .. delim
      count = count + 1
      state.next = state.next + 1
    else
      out[n] = text:sub(s, e)
    end
    pos = e + 1
  end

  if count == 0 then
    return text, 0
  end
  n = n + 1
  out[n] = text:sub(pos)
  return table.concat(out), count
end

--- Renumber rows `[srow, erow]` (0-based, inclusive) as one sequence — the
--- linewise (`V`) case, e.g. a selected block of numbered Markdown headlines.
---@param bufnr integer
---@param srow integer
---@param erow integer
---@param opts CascadeSequenceOpts
---@return boolean changed
function M.range(bufnr, srow, erow, opts)
  local lines = vim.api.nvim_buf_get_lines(bufnr, srow, erow + 1, false)
  local state = {}
  local changed = false
  for i = 1, #lines do
    local new = M.rewrite(lines[i], opts, state)
    if new ~= lines[i] then
      lines[i] = new
      changed = true
    end
  end
  if not changed then
    return false
  end
  return (pcall(vim.api.nvim_buf_set_lines, bufnr, srow, erow + 1, false, lines))
end

--- Renumber the byte range `[scol, ecol]` (0-based, inclusive) of `row` — the
--- same-line charwise (`v`) case, e.g. inline numbers picked out of the middle
--- of a prose line. Writes with `nvim_buf_set_text` so the rest of the line is
--- untouched.
---
--- The replacement can change the span's width (`9.` -> `10.`), so the new end
--- column is returned for the caller to re-anchor the selection on.
---@param bufnr integer
---@param row integer
---@param scol integer
---@param ecol integer
---@param opts CascadeSequenceOpts
---@return boolean changed, integer ecol # unchanged `ecol` when nothing was rewritten.
function M.span(bufnr, row, scol, ecol, opts)
  local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
  if not line then
    return false, ecol
  end
  local seg = line:sub(scol + 1, ecol + 1)
  local new = M.rewrite(seg, opts, {})
  if new == seg then
    return false, ecol
  end
  if not pcall(vim.api.nvim_buf_set_text, bufnr, row, scol, row, ecol + 1, { new }) then
    return false, ecol
  end
  return true, scol + #new - 1
end

return M

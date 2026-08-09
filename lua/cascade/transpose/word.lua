---@module 'cascade.transpose.word'
--- Swap a word, or a same-line selection, with its immediate left/right
--- neighbor word.
---
--- "Word" means an `'iskeyword'` run (`\k\+`, same span `cascade.cycle.token`
--- uses), so this respects the buffer's keyword definition rather than
--- native `w`/`b` punctuation rules. The separator text between the two
--- words (whitespace, punctuation, ...) moves as a block and is never
--- rewritten -- only the two words trade places, mirroring how
--- `cascade.transpose.char` swaps two characters around nothing (chars have
--- no gap between them). Byte-column throughout: `matchstrpos` and
--- `string.sub` already agree on byte offsets, so no `strcharpart`/`charidx`
--- conversion is needed (unlike `transpose.char`, which slices character-by-
--- character). No-op when the cursor isn't on a word, there's no neighbor
--- word left on the line, or the selection spans multiple lines.

local token = require("cascade.cycle.token")

local M = {}

local WORD_PAT = [[\k\+]]

--- Swap the word at `ctx`'s cursor with its right (`dir = 1`) or left
--- (`dir = -1`) neighbor word on the same line. Moves the cursor to the
--- start of the moved word.
---@param ctx CascadeContext
---@param dir integer
---@return boolean handled
function M.word(ctx, dir)
  local line = ctx.line
  local s0, e0 = token.span(line, ctx.col0)
  if not s0 then
    return false
  end

  local new_line, new_col0
  if dir > 0 then
    local mt = vim.fn.matchstrpos(line, WORD_PAT, e0)
    local ntext, ns, ne = mt[1], mt[2], mt[3]
    if ns == -1 then
      return false
    end
    local before = line:sub(1, s0)
    local cur = line:sub(s0 + 1, e0)
    local gap = line:sub(e0 + 1, ns)
    local after = line:sub(ne + 1)
    new_line = before .. ntext .. gap .. cur .. after
    new_col0 = s0 + #ntext + #gap
  else
    local prev_s, prev_e, prev_text
    local pos = 0
    while true do
      local mt = vim.fn.matchstrpos(line, WORD_PAT, pos)
      local text, ms, me = mt[1], mt[2], mt[3]
      if ms == -1 or ms >= s0 then
        break
      end
      prev_s, prev_e, prev_text = ms, me, text
      pos = me
    end
    if not prev_s then
      return false
    end
    local before = line:sub(1, prev_s)
    local gap = line:sub(prev_e + 1, s0)
    local cur = line:sub(s0 + 1, e0)
    local after = line:sub(e0 + 1)
    new_line = before .. cur .. gap .. prev_text .. after
    new_col0 = prev_s
  end

  vim.api.nvim_buf_set_lines(ctx.bufnr, ctx.row0, ctx.row0 + 1, false, { new_line })
  vim.api.nvim_win_set_cursor(0, { ctx.row0 + 1, new_col0 })
  return true
end

--- Swap a same-line selection with the single word immediately to its right
--- (`dir = 1`) or left (`dir = -1`). No-op across multiple lines or when
--- there's no neighbor word. The swapped-in neighbor moves to the
--- selection's old slot, so the selected text itself shifts -- callers that
--- need to keep the same *text* selected afterwards should reselect
--- `new_scol`/`new_ecol`, not the original `scol0`/`ecol0`.
---@param bufnr integer
---@param row0 integer # 0-based line.
---@param scol0 integer # 0-based byte column, selection start.
---@param ecol0 integer # 0-based byte column, selection end (inclusive).
---@param dir integer
---@return boolean changed, integer|nil new_scol, integer|nil new_ecol
function M.word_selection(bufnr, row0, scol0, ecol0, dir)
  local line = vim.api.nvim_buf_get_lines(bufnr, row0, row0 + 1, false)[1]
  if not line then
    return false
  end
  if scol0 > ecol0 then
    scol0, ecol0 = ecol0, scol0
  end

  local new_line, new_scol, new_ecol
  if dir > 0 then
    local mt = vim.fn.matchstrpos(line, WORD_PAT, ecol0 + 1)
    local ntext, ns, ne = mt[1], mt[2], mt[3]
    if ns == -1 then
      return false
    end
    local before = line:sub(1, scol0)
    local sel = line:sub(scol0 + 1, ecol0 + 1)
    local gap = line:sub(ecol0 + 2, ns)
    local after = line:sub(ne + 1)
    new_line = before .. ntext .. gap .. sel .. after
    new_scol = #before + #ntext + #gap
    new_ecol = new_scol + #sel - 1
  else
    local prev_s, prev_e, prev_text
    local pos = 0
    while true do
      local mt = vim.fn.matchstrpos(line, WORD_PAT, pos)
      local text, ms, me = mt[1], mt[2], mt[3]
      if ms == -1 or ms > scol0 then
        break
      end
      if me <= scol0 then
        prev_s, prev_e, prev_text = ms, me, text
      end
      pos = me
    end
    if not prev_s then
      return false
    end
    local before = line:sub(1, prev_s)
    local gap = line:sub(prev_e + 1, scol0)
    local sel = line:sub(scol0 + 1, ecol0 + 1)
    local after = line:sub(ecol0 + 2)
    new_line = before .. sel .. gap .. prev_text .. after
    new_scol = #before
    new_ecol = new_scol + #sel - 1
  end

  vim.api.nvim_buf_set_lines(bufnr, row0, row0 + 1, false, { new_line })
  return true, new_scol, new_ecol
end

return M

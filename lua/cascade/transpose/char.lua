---@module 'cascade.transpose.char'
---@brief Swap a character, or a same-line selection, with its immediate
---left/right neighbor.
---@description
--- UTF-8 safe: works in character space (`strcharpart`/`charidx`/`byteidx`),
--- not byte space, so a multibyte character (e.g. "ä") moves as one unit
--- instead of being torn apart. A pure line-rewrite, unlike the classic
--- `xp`/`xhP` trick — it never touches the unnamed register. No-op at a line
--- boundary (nothing to swap with) or, for `selection`, across multiple
--- lines: there is no single well-defined neighbor there.

local M = {}

--- Swap the character at `ctx`'s cursor with its right (`dir = 1`) or left
--- (`dir = -1`) neighbor on the same line. Moves the cursor to follow it.
---@param ctx CascadeContext
---@param dir integer
---@return boolean handled
function M.char(ctx, dir)
  local line = ctx.line
  local total = vim.fn.strchars(line)
  local idx = vim.fn.charidx(line, ctx.col0)
  if idx < 0 then
    return false
  end

  local new_line, new_idx
  if dir > 0 then
    if idx + 1 >= total then
      return false
    end
    local before = vim.fn.strcharpart(line, 0, idx)
    local cur = vim.fn.strcharpart(line, idx, 1)
    local nxt = vim.fn.strcharpart(line, idx + 1, 1)
    local after = vim.fn.strcharpart(line, idx + 2)
    new_line = before .. nxt .. cur .. after
    new_idx = idx + 1
  else
    if idx < 1 then
      return false
    end
    local before = vim.fn.strcharpart(line, 0, idx - 1)
    local prev = vim.fn.strcharpart(line, idx - 1, 1)
    local cur = vim.fn.strcharpart(line, idx, 1)
    local after = vim.fn.strcharpart(line, idx + 1)
    new_line = before .. cur .. prev .. after
    new_idx = idx - 1
  end

  vim.api.nvim_buf_set_lines(ctx.bufnr, ctx.row0, ctx.row0 + 1, false, { new_line })
  vim.api.nvim_win_set_cursor(0, { ctx.row0 + 1, vim.fn.byteidx(new_line, new_idx) })
  return true
end

--- Swap a same-line selection with the single character immediately to its
--- right (`dir = 1`) or left (`dir = -1`). No-op across multiple lines or at
--- the line boundary.
---@param bufnr integer
---@param row0 integer # 0-based line.
---@param scol0 integer # 0-based byte column, selection start.
---@param ecol0 integer # 0-based byte column, selection end (inclusive).
---@param dir integer
---@return boolean changed
function M.selection(bufnr, row0, scol0, ecol0, dir)
  local line = vim.api.nvim_buf_get_lines(bufnr, row0, row0 + 1, false)[1]
  if not line then
    return false
  end
  local sc, ec = vim.fn.charidx(line, scol0), vim.fn.charidx(line, ecol0)
  if sc < 0 or ec < 0 then
    return false
  end
  if sc > ec then
    sc, ec = ec, sc
  end
  local total = vim.fn.strchars(line)

  local new_line
  if dir > 0 then
    if ec + 1 >= total then
      return false
    end
    local before = vim.fn.strcharpart(line, 0, sc)
    local sel = vim.fn.strcharpart(line, sc, ec - sc + 1)
    local nxt = vim.fn.strcharpart(line, ec + 1, 1)
    local after = vim.fn.strcharpart(line, ec + 2)
    new_line = before .. nxt .. sel .. after
  else
    if sc < 1 then
      return false
    end
    local before = vim.fn.strcharpart(line, 0, sc - 1)
    local prev = vim.fn.strcharpart(line, sc - 1, 1)
    local sel = vim.fn.strcharpart(line, sc, ec - sc + 1)
    local after = vim.fn.strcharpart(line, ec + 1)
    new_line = before .. sel .. prev .. after
  end

  vim.api.nvim_buf_set_lines(bufnr, row0, row0 + 1, false, { new_line })
  return true
end

return M

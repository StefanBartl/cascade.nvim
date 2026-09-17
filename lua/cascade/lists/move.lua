---@module 'cascade.lists.move'
--- Move a line / selection up or down, reindent, and renumber lists.
---
--- Wraps Vim's `:move` so that moving an ordered list item re-sequences the
--- block afterwards (the renumber the plain `:m`+`==` mapping can't do). Works on
--- a single line (normal mode) and a line range (visual mode); reindenting with
--- `=` is a no-op in plain-text/markdown buffers and proper reindent in code.

local marker = require("cascade.lists.marker")
local renumber = require("cascade.lists.renumber")
local transform = require("cascade.lists.transform")

local M = {}

---@internal
--- Tree-renumber the list block containing `row0` (0-based), if it is a list.
---@param bufnr integer
---@param row0 integer
---@param opts CascadeListOpts
---@param forced_base_start integer|nil # See `base_start_before_move` below.
---@return nil
local function renumber_block(bufnr, row0, opts, forced_base_start)
  if not renumber.at(opts, "edit") then
    return
  end
  local l = vim.api.nvim_buf_get_lines(bufnr, row0, row0 + 1, false)[1]
  if l and marker.parse(l, opts) then
    local s, e = transform.block_range(bufnr, row0, opts)
    if s and e then
      pcall(renumber.tree, bufnr, s, e, opts, nil, forced_base_start)
    end
  end
end

---@internal
--- The block's base-level start value *before* the move that is about to
--- reorder it. `renumber.tree` normally derives that value by scanning for
--- whichever line is physically first in the block -- but a move changes
--- which line that is, so scanning *after* the move picks up whatever number
--- the newly-first line happened to carry, one off from the block's actual
--- start. Read here, before anything moves, and threaded through to
--- `renumber_block` as `forced_base_start` so the anchor survives the reorder
--- instead of creeping by one with every repeated move in the same direction.
---@param bufnr integer
---@param row0 integer
---@param opts CascadeListOpts
---@return integer|nil
local function base_start_before_move(bufnr, row0, opts)
  local l = vim.api.nvim_buf_get_lines(bufnr, row0, row0 + 1, false)[1]
  if not (l and marker.parse(l, opts)) then
    return nil
  end
  local s, e = transform.block_range(bufnr, row0, opts)
  if not (s and e) then
    return nil
  end
  return renumber.peek_base_start(bufnr, s, e, opts)
end

--- Move the current line up (dir -1) or down (+1); reindent; renumber.
---@param bufnr integer
---@param dir integer
---@param opts CascadeListOpts
---@return boolean handled
function M.line(bufnr, dir, opts)
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  local total = vim.api.nvim_buf_line_count(bufnr)
  if (dir < 0 and lnum <= 1) or (dir > 0 and lnum >= total) then
    return false
  end
  local forced_base_start = base_start_before_move(bufnr, lnum - 1, opts)
  vim.cmd("keepjumps move " .. (dir < 0 and ".-2" or ".+1"))
  vim.cmd("keepjumps normal! ==")
  renumber_block(bufnr, vim.api.nvim_win_get_cursor(0)[1] - 1, opts, forced_base_start)
  return true
end

--- Move a line range up/down; reindent; renumber; reselect linewise.
---@param bufnr integer
---@param srow integer # 0-based inclusive
---@param erow integer # 0-based inclusive
---@param dir integer
---@param opts CascadeListOpts
---@return boolean handled
function M.selection(bufnr, srow, erow, dir, opts)
  local s, e = srow + 1, erow + 1
  local total = vim.api.nvim_buf_line_count(bufnr)
  if (dir < 0 and s <= 1) or (dir > 0 and e >= total) then
    return false
  end
  local forced_base_start = base_start_before_move(bufnr, srow, opts)
  local dest = dir < 0 and (s - 2) or (e + 1)
  vim.cmd(string.format("keepjumps %d,%dmove %d", s, e, dest))

  local ns = dir < 0 and (s - 1) or (s + 1)
  local ne = dir < 0 and (e - 1) or (e + 1)
  vim.cmd(string.format("keepjumps normal! %dGV%dG=", ns, ne)) -- reindent (no-op in markdown)
  renumber_block(bufnr, ns - 1, opts, forced_base_start)
  vim.cmd(string.format("keepjumps normal! %dGV%dG", ns, ne)) -- reselect moved block
  return true
end

return M

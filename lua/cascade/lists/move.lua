---@module 'cascade.lists.move'
---@brief Move a line / selection up or down, reindent, and renumber lists.
---@description
--- Wraps Vim's `:move` so that moving an ordered list item re-sequences the
--- block afterwards (the renumber the plain `:m`+`==` mapping can't do). Works on
--- a single line (normal mode) and a line range (visual mode); reindenting with
--- `=` is a no-op in plain-text/markdown buffers and proper reindent in code.

local marker = require("cascade.lists.marker")
local renumber = require("cascade.lists.renumber")
local transform = require("cascade.lists.transform")

local M = {}

--- Tree-renumber the list block containing `row0` (0-based), if it is a list.
---@param bufnr integer
---@param row0 integer
---@param opts CascadeListOpts
---@return nil
local function renumber_block(bufnr, row0, opts)
  if not opts.renumber then
    return
  end
  local l = vim.api.nvim_buf_get_lines(bufnr, row0, row0 + 1, false)[1]
  if l and marker.parse(l, opts) then
    local s, e = transform.block_range(bufnr, row0, opts)
    if s and e then
      pcall(renumber.tree, bufnr, s, e, opts)
    end
  end
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
  vim.cmd("keepjumps move " .. (dir < 0 and ".-2" or ".+1"))
  vim.cmd("keepjumps normal! ==")
  renumber_block(bufnr, vim.api.nvim_win_get_cursor(0)[1] - 1, opts)
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
  local dest = dir < 0 and (s - 2) or (e + 1)
  vim.cmd(string.format("keepjumps %d,%dmove %d", s, e, dest))

  local ns = dir < 0 and (s - 1) or (s + 1)
  local ne = dir < 0 and (e - 1) or (e + 1)
  vim.cmd(string.format("keepjumps normal! %dGV%dG=", ns, ne)) -- reindent (no-op in markdown)
  renumber_block(bufnr, ns - 1, opts)
  vim.cmd(string.format("keepjumps normal! %dGV%dG", ns, ne)) -- reselect moved block
  return true
end

return M

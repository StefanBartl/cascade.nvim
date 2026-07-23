---@module 'cascade.lists.indent'
---@brief Indent / dedent list lines by N shift units, with indent-aware renumber.
---@description
--- Shifts a line (or a range) by `count` shift units, respecting 'expandtab' and
--- 'shiftwidth', then renumbers the enclosing list block with the per-level tree
--- renumber so every nesting level forms a clean sequence. Works on single lines
--- (normal mode, cursor preserved) and ranges (visual mode). Non-list lines are
--- still shifted; renumbering only runs on list blocks.

local marker = require("cascade.lists.marker")
local renumber = require("cascade.lists.renumber")
local transform = require("cascade.lists.transform")

local M = {}

--- Read a buffer line (0-based), or nil.
---@param bufnr integer
---@param r integer
---@return string|nil
local function line_at(bufnr, r)
  return vim.api.nvim_buf_get_lines(bufnr, r, r + 1, false)[1]
end

--- The buffer's effective shiftwidth.
---@param bufnr integer
---@return integer
local function shift_width(bufnr)
  local bo = vim.bo[bufnr]
  local sw = bo.shiftwidth
  if sw == 0 then
    sw = bo.tabstop
  end
  return sw
end

--- Shift a line's leading indent by `count` units in direction `dir`.
---@param line string
---@param dir integer # 1 = indent, -1 = dedent.
---@param count integer
---@param bufnr integer
---@return string new_line, integer delta # delta = chars added (+) / removed (-) at front.
local function apply_shift(line, dir, count, bufnr)
  local sw = shift_width(bufnr)
  if dir > 0 then
    local unit = vim.bo[bufnr].expandtab and string.rep(" ", sw) or "\t"
    local add = unit:rep(count)
    return add .. line, #add
  end
  local removed = 0
  for _ = 1, count do
    if line:sub(1, 1) == "\t" then
      line = line:sub(2)
      removed = removed + 1
    else
      local n = 0
      while n < sw and line:sub(1, 1) == " " do
        line = line:sub(2)
        n = n + 1
      end
      removed = removed + n
      if n == 0 then
        break
      end
    end
  end
  return line, -removed
end

--- Extent of the child block that follows an item at indent width `orig_w`:
--- every line right after `row0` that is either deeper-indented (a nested
--- sub-item, or the item's own wrapped continuation text) or a blank line
--- within `lists.renumber.blank_break` tolerance belongs to it. A non-blank
--- line at `orig_w` or shallower (a sibling, or the enclosing block's end)
--- stops it.
---@param bufnr integer
---@param row0 integer
---@param orig_w integer
---@param opts CascadeListOpts
---@return integer erow # last row (0-based, inclusive) of the child block; row0 if none.
local function subtree_end(bufnr, row0, orig_w, opts)
  local total = vim.api.nvim_buf_line_count(bufnr)
  local max_blank = marker.blank_run(opts)
  local e, blanks = row0, 0
  while e + 1 < total do
    local l = line_at(bufnr, e + 1)
    if l == nil then
      break
    end
    if l == "" then
      blanks = blanks + 1
      if blanks > max_blank then
        break
      end
    else
      blanks = 0
      local w = #(l:match("^(%s*)") or "")
      if w <= orig_w then
        break
      end
    end
    e = e + 1
  end
  return e
end

--- Tree-renumber the list block that contains the first list line in the range.
---@param bufnr integer
---@param srow integer
---@param erow integer
---@param opts CascadeListOpts
---@return nil
local function renumber_block(bufnr, srow, erow, opts)
  if not renumber.at(opts, "edit") then
    return
  end
  for r = srow, erow do
    local l = line_at(bufnr, r)
    if l and marker.parse(l, opts) then
      local s, e = transform.block_range(bufnr, r, opts)
      if s and e then
        pcall(renumber.tree, bufnr, s, e, opts)
      end
      return
    end
  end
end

--- Shift a single list line (and its subtree: nested children / wrapped
--- continuation text — see `subtree_end`) and keep the cursor on the same
--- character.
---@param ctx CascadeContext
---@param opts CascadeListOpts
---@param count integer
---@param dir integer # 1 indent, -1 dedent.
---@return boolean handled
function M.shift_line(ctx, opts, count, dir)
  local m = marker.parse(ctx.line, opts)
  if not m then
    return false
  end
  local new, delta = apply_shift(ctx.line, dir, count, ctx.bufnr)
  if delta == 0 then
    return false
  end
  local child_end = subtree_end(ctx.bufnr, ctx.row0, #m.indent, opts)
  vim.api.nvim_buf_set_lines(ctx.bufnr, ctx.row0, ctx.row0 + 1, false, { new })
  for r = ctx.row0 + 1, child_end do
    local l = line_at(ctx.bufnr, r)
    if l and l ~= "" then
      local shifted = apply_shift(l, dir, count, ctx.bufnr)
      if shifted ~= l then
        vim.api.nvim_buf_set_lines(ctx.bufnr, r, r + 1, false, { shifted })
      end
    end
  end
  vim.api.nvim_win_set_cursor(0, { ctx.row0 + 1, math.max(0, ctx.col0 + delta) })
  renumber_block(ctx.bufnr, ctx.row0, ctx.row0, opts)
  return true
end

--- Shift every (non-empty) line in `[srow, erow]`, then renumber the block.
--- Used for visual selections and range commands; works on non-list lines too,
--- but only renumbers when `renumber_ok` (the caller's filetype gate) is true.
---@param bufnr integer
---@param srow integer
---@param erow integer
---@param dir integer
---@param count integer
---@param opts CascadeListOpts
---@param renumber_ok boolean
---@return nil
function M.shift_range(bufnr, srow, erow, dir, count, opts, renumber_ok)
  for r = srow, erow do
    local l = line_at(bufnr, r)
    if l and l ~= "" then
      local new = apply_shift(l, dir, count, bufnr)
      if new ~= l then
        vim.api.nvim_buf_set_lines(bufnr, r, r + 1, false, { new })
      end
    end
  end
  if renumber_ok then
    renumber_block(bufnr, srow, erow, opts)
  end
end

return M

---@module 'cascade.lists.indent'
---@brief Indent / dedent a list line by one shift unit, then renumber.
---@description
--- Shifts the whole line by one `shiftwidth` unit (respecting `expandtab`) and
--- keeps the cursor on the same character. After the shift, both the line's new
--- level and the level it left are renumbered so ordered lists stay consistent.

local marker = require("cascade.lists.marker")
local renumber = require("cascade.lists.renumber")

local M = {}

--- Resolve the buffer's one-step indent unit.
---@param bufnr integer
---@return string
local function indent_unit(bufnr)
  local bo = vim.bo[bufnr]
  local sw = bo.shiftwidth
  if sw == 0 then
    sw = bo.tabstop
  end
  if bo.expandtab then
    return string.rep(" ", sw)
  end
  return "\t"
end

--- Renumber the ordered block at `row0` and at the line above it (the level the
--- shifted line may have left behind).
---@param bufnr integer
---@param row0 integer
---@param opts CascadeListOpts
---@return nil
local function renumber_around(bufnr, row0, opts)
  if not opts.renumber then
    return
  end
  pcall(renumber.run, bufnr, row0, opts)
  if row0 - 1 >= 0 then
    pcall(renumber.run, bufnr, row0 - 1, opts)
  end
end

--- Indent the cursor line by one unit.
---@param ctx CascadeContext
---@param opts CascadeListOpts
---@return boolean handled
function M.indent(ctx, opts)
  if not marker.parse(ctx.line, opts) then
    return false
  end
  local unit = indent_unit(ctx.bufnr)
  vim.api.nvim_buf_set_lines(ctx.bufnr, ctx.row0, ctx.row0 + 1, false, { unit .. ctx.line })
  vim.api.nvim_win_set_cursor(0, { ctx.row0 + 1, ctx.col0 + #unit })
  renumber_around(ctx.bufnr, ctx.row0, opts)
  return true
end

--- Dedent the cursor line by one unit (no-op if already flush left).
---@param ctx CascadeContext
---@param opts CascadeListOpts
---@return boolean handled
function M.dedent(ctx, opts)
  if not marker.parse(ctx.line, opts) then
    return false
  end
  local line = ctx.line
  local removed = 0
  if line:sub(1, 1) == "\t" then
    line = line:sub(2)
    removed = 1
  else
    local bo = vim.bo[ctx.bufnr]
    local sw = bo.shiftwidth
    if sw == 0 then
      sw = bo.tabstop
    end
    while removed < sw and line:sub(1, 1) == " " do
      line = line:sub(2)
      removed = removed + 1
    end
  end
  if removed == 0 then
    return false
  end
  vim.api.nvim_buf_set_lines(ctx.bufnr, ctx.row0, ctx.row0 + 1, false, { line })
  vim.api.nvim_win_set_cursor(0, { ctx.row0 + 1, math.max(0, ctx.col0 - removed) })
  renumber_around(ctx.bufnr, ctx.row0, opts)
  return true
end

return M

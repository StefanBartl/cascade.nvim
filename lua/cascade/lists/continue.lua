---@module 'cascade.lists.continue'
---@brief List continuation for <CR>, o and O, with empty-bullet deletion.
---@description
--- Each entry point returns true when it handled the key (so the dispatcher
--- skips the native fallback). On a non-empty ordered item the new marker is the
--- incremented sibling and the block is renumbered; on an empty item `<CR>`
--- removes the bullet to terminate the list (when `continue.delete_empty`).

local marker = require("cascade.lists.marker")
local renumber = require("cascade.lists.renumber")

local M = {}

--- Renumber the block at `row0` if ordered renumbering is enabled.
---@param bufnr integer
---@param row0 integer
---@param opts CascadeListOpts
---@return nil
local function maybe_renumber(bufnr, row0, opts)
  if renumber.at(opts, "edit") then
    pcall(renumber.run, bufnr, row0, opts)
  end
end

--- Handle <CR> in insert mode on a list line.
---@param ctx CascadeContext
---@param opts CascadeListOpts
---@return boolean handled
function M.cr(ctx, opts)
  local m = marker.parse(ctx.line, opts)
  if not m then
    return false
  end

  -- Empty bullet: terminate the list by clearing the marker.
  if marker.is_empty(m) then
    if not opts.continue.delete_empty then
      return false
    end
    vim.api.nvim_buf_set_lines(ctx.bufnr, ctx.row0, ctx.row0 + 1, false, { "" })
    vim.api.nvim_win_set_cursor(0, { ctx.row0 + 1, 0 })
    return true
  end

  -- Continue: split the line at the cursor and prefix the tail with the next marker.
  local before = ctx.line:sub(1, ctx.col0)
  local after = ctx.line:sub(ctx.col0 + 1)
  local prefix = marker.render(marker.advance(m, opts))
  vim.api.nvim_buf_set_lines(ctx.bufnr, ctx.row0, ctx.row0 + 1, false, { before, prefix .. after })
  vim.api.nvim_win_set_cursor(0, { ctx.row0 + 2, #prefix })
  maybe_renumber(ctx.bufnr, ctx.row0 + 1, opts)
  return true
end

--- Handle `o` (open line below) on a list line.
---@param ctx CascadeContext
---@param opts CascadeListOpts
---@return boolean handled
function M.o(ctx, opts)
  local m = marker.parse(ctx.line, opts)
  if not m then
    return false
  end
  local prefix = marker.render(marker.advance(m, opts))
  vim.api.nvim_buf_set_lines(ctx.bufnr, ctx.row0 + 1, ctx.row0 + 1, false, { prefix })
  vim.api.nvim_win_set_cursor(0, { ctx.row0 + 2, #prefix })
  maybe_renumber(ctx.bufnr, ctx.row0 + 1, opts)
  vim.cmd("startinsert!")
  return true
end

--- Handle `O` (open line above) on a list line.
---@param ctx CascadeContext
---@param opts CascadeListOpts
---@return boolean handled
function M.O(ctx, opts)
  local m = marker.parse(ctx.line, opts)
  if not m then
    return false
  end
  -- New item takes the current marker's slot; renumber pushes the rest down.
  local fresh = { indent = m.indent, kind = m.kind, marker = m.marker, delim = m.delim, text = "" }
  if m.checkbox ~= nil then
    fresh.checkbox = opts.checkbox.states[1]
  end
  local prefix = marker.render(fresh)
  vim.api.nvim_buf_set_lines(ctx.bufnr, ctx.row0, ctx.row0, false, { prefix })
  vim.api.nvim_win_set_cursor(0, { ctx.row0 + 1, #prefix })
  maybe_renumber(ctx.bufnr, ctx.row0, opts)
  vim.cmd("startinsert!")
  return true
end

return M

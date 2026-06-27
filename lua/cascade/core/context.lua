---@module 'cascade.core.context'
---@brief One-shot cursor/buffer context object.
---@description
--- Both feature domains repeatedly need the same primitives: the buffer handle,
--- the cursor position, the current line and the filetype. Building them once
--- per action (instead of scattering `nvim_*`/`vim.fn.*` calls) keeps the hot
--- path cheap and the data flow explicit.

---@class CascadeContext
local Context = {}
Context.__index = Context

--- Build a context snapshot for the current window/cursor.
---@param bufnr integer|nil # Defaults to the current buffer.
---@return CascadeContext
function Context.new(bufnr)
  local self = setmetatable({}, Context)
  self.bufnr = (bufnr and bufnr ~= 0) and bufnr or vim.api.nvim_get_current_buf()
  local cur = vim.api.nvim_win_get_cursor(0)
  self.row0 = cur[1] - 1
  self.col0 = cur[2]
  self.line = vim.api.nvim_get_current_line()
  self.ft = vim.bo[self.bufnr].filetype
  return self
end

--- Whether a buffer can be safely mutated (normal, modifiable, not read-only).
---@param bufnr integer|nil
---@return boolean
function Context.writable(bufnr)
  bufnr = (bufnr and bufnr ~= 0) and bufnr or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end
  local bo = vim.bo[bufnr]
  if bo.buftype ~= "" then
    return false
  end
  if not bo.modifiable then
    return false
  end
  if bo.readonly then
    return false
  end
  return true
end

return Context

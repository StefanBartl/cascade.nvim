---@module 'cascade.util.lib'
---@brief Soft, guarded bridge to the optional `lib.nvim` helper library.
---@description
--- cascade.nvim prefers the user's `lib.*` helpers (`lib.map`, `lib.notify`, ...)
--- when present, but must stay fully functional standalone. Every accessor here
--- probes the corresponding `lib` module with `pcall` and falls back to the
--- native Neovim API. No hard dependency is ever introduced.
---@see lib-nvim-dependency

local M = {}

--- Resolve a sub-module of `lib` once, swallowing load errors.
---@param name string
---@return table|nil
local function try_require(name)
  local ok, mod = pcall(require, name)
  if ok and type(mod) == "table" then
    return mod
  end
  return nil
end

--- Notify the user. Uses `lib.notify` if available, else `vim.notify`.
---@param msg string
---@param level integer|nil # vim.log.levels.*; defaults to INFO
---@return nil
function M.notify(msg, level)
  level = level or vim.log.levels.INFO
  local lib = try_require("lib.notify")
  if lib and type(lib.notify) == "function" then
    pcall(lib.notify, msg, level)
    return
  end
  vim.notify(("[cascade] %s"):format(msg), level)
end

--- Set a keymap. Uses `lib.map` if available, else `vim.keymap.set`.
---@param mode string|string[]
---@param lhs string
---@param rhs string|function
---@param opts table|nil
---@return nil
function M.map(mode, lhs, rhs, opts)
  opts = opts or {}
  local lib = try_require("lib.map")
  if lib and type(lib.map) == "function" then
    pcall(lib.map, mode, lhs, rhs, opts)
    return
  end
  vim.keymap.set(mode, lhs, rhs, opts)
end

--- Create an autocommand group. Returns the group id.
---@param name string
---@return integer
function M.augroup(name)
  local lib = try_require("lib.augroup")
  if lib and type(lib.augroup) == "function" then
    local ok, id = pcall(lib.augroup, name)
    if ok and type(id) == "number" then
      return id
    end
  end
  return vim.api.nvim_create_augroup(name, { clear = true })
end

return M

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

--- Feed a native key sequence without remapping, queued to run once the
--- current mapping function returns.
---@param keys string
---@return nil
local function feed(keys)
  vim.api.nvim_feedkeys(vim.keycode(keys), "n", false)
end

--- Standalone fallback for `lib.nvim.selection.lines`.
---@return integer srow, integer erow
local function lines_fallback()
  local a, b = vim.fn.line("v") - 1, vim.fn.line(".") - 1
  if a > b then
    a, b = b, a
  end
  return a, b
end

--- Standalone fallback for `lib.nvim.selection.reselect_lines` (see there
--- for the full rationale: `gv` is unreliable mid-selection since its marks
--- are only set once Visual mode ends).
---@param srow integer
---@param erow integer
---@return nil
local function reselect_lines_fallback(srow, erow)
  feed(string.format("<Esc>%dGV%dG", srow + 1, erow + 1))
end

--- Standalone fallback for `lib.nvim.selection.chars`.
---@return integer|nil row, integer|nil scol, integer|nil ecol
local function chars_fallback()
  if vim.fn.mode() ~= "v" then
    return nil
  end
  local row_v, col_v = vim.fn.line("v"), vim.fn.col("v")
  local row_d, col_d = vim.fn.line("."), vim.fn.col(".")
  if row_v ~= row_d then
    return nil
  end
  local scol, ecol = col_v - 1, col_d - 1
  if scol > ecol then
    scol, ecol = ecol, scol
  end
  return row_d - 1, scol, ecol
end

--- Standalone fallback for `lib.nvim.selection.reselect_chars`.
---@param row integer
---@param scol integer
---@param ecol integer
---@return nil
local function reselect_chars_fallback(row, scol, ecol)
  local line = vim.api.nvim_buf_get_lines(0, row, row + 1, false)[1] or ""
  local sc = math.max(vim.fn.charidx(line, scol), 0)
  local ec = math.max(vim.fn.charidx(line, ecol), sc)
  local keys = string.format("<Esc>%dG0", row + 1)
  if sc > 0 then
    keys = keys .. sc .. "l"
  end
  keys = keys .. "v"
  if ec > sc then
    keys = keys .. (ec - sc) .. "l"
  end
  feed(keys)
end

--- 0-based inclusive row range of the current Visual selection. Uses
--- `lib.nvim.selection` if available, else an inline equivalent.
---@return integer srow, integer erow
function M.lines()
  local lib = try_require("lib.nvim.selection")
  if lib and type(lib.lines) == "function" then
    local ok, srow, erow = pcall(lib.lines)
    if ok then
      return srow, erow
    end
  end
  return lines_fallback()
end

--- Restore a linewise (`V`) selection over `[srow, erow]` (0-based
--- inclusive). Uses `lib.nvim.selection` if available, else an inline
--- equivalent.
---@param srow integer
---@param erow integer
---@return nil
function M.reselect_lines(srow, erow)
  local lib = try_require("lib.nvim.selection")
  if lib and type(lib.reselect_lines) == "function" then
    local ok = pcall(lib.reselect_lines, srow, erow)
    if ok then
      return
    end
  end
  reselect_lines_fallback(srow, erow)
end

--- Run `fn(srow, erow)` against the current Visual selection's 0-based
--- inclusive row range, then reselect the same rows linewise.
---@generic T
---@param fn fun(srow: integer, erow: integer): T
---@return T
function M.keep_lines(fn)
  local srow, erow = M.lines()
  local ret = fn(srow, erow)
  M.reselect_lines(srow, erow)
  return ret
end

--- 0-based row and inclusive byte-column range of the current Visual
--- selection, if (and only if) it is charwise and confined to one line.
--- Uses `lib.nvim.selection` if available, else an inline equivalent.
---@return integer|nil row, integer|nil scol, integer|nil ecol
function M.chars()
  local lib = try_require("lib.nvim.selection")
  if lib and type(lib.chars) == "function" then
    local ok, row, scol, ecol = pcall(lib.chars)
    if ok then
      return row, scol, ecol
    end
  end
  return chars_fallback()
end

--- Restore a charwise (`v`) selection spanning byte columns `[scol, ecol]`
--- (0-based inclusive) on `row`. Uses `lib.nvim.selection` if available,
--- else an inline equivalent.
---@param row integer
---@param scol integer
---@param ecol integer
---@return nil
function M.reselect_chars(row, scol, ecol)
  local lib = try_require("lib.nvim.selection")
  if lib and type(lib.reselect_chars) == "function" then
    local ok = pcall(lib.reselect_chars, row, scol, ecol)
    if ok then
      return
    end
  end
  reselect_chars_fallback(row, scol, ecol)
end

--- Run `fn(row, scol, ecol)` against the current same-line charwise
--- selection, then reselect the *same* byte-column span. `applicable` is
--- false (and `fn` is not called) when the selection isn't same-line
--- charwise. Only correct when `fn` rewrites the selected text in place
--- without shifting it — for a mutation that *moves* the selected text
--- (e.g. swapping it with a neighbor), reselect the returned new bounds
--- yourself via `reselect_chars` instead.
---@generic T
---@param fn fun(row: integer, scol: integer, ecol: integer): T
---@return T|nil ret, boolean applicable
function M.keep_chars(fn)
  local row, scol, ecol = M.chars()
  if not row then
    return nil, false
  end
  local ret = fn(row, scol, ecol)
  M.reselect_chars(row, scol, ecol)
  return ret, true
end

return M

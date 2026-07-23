---@module 'cascade.util.lib'
---@brief Soft, guarded bridge to a handful of `lib.nvim` helpers.
---@description
--- `lib.nvim` itself is now a required dependency (the :Cascade command is
--- built on lib.nvim.usercmd.composer, see bindings/usrcmds.lua) — but these
--- specific accessors (`lib.map`, `lib.notify`, ...) stay soft-guarded for
--- callers that want a native-API fallback instead of a hard call, and each
--- probes its module with `pcall` accordingly.
---@see lib-nvim-dependency

local M = {}

--- Resolve a sub-module of `lib` once, swallowing load errors. Accepts both
--- table modules (`lib.nvim.notify`, `lib.nvim.autocmd.augroup`) and bare
--- function modules (`lib.nvim.map` returns a function, not a table).
---@param name string
---@return table|function|nil
local function try_require(name)
  local ok, mod = pcall(require, name)
  if ok and (type(mod) == "table" or type(mod) == "function") then
    return mod
  end
  return nil
end

--- Notify the user. Uses `lib.nvim.notify` if available, else `vim.notify`.
---@param msg string
---@param level integer|nil # vim.log.levels.*; defaults to INFO
---@return nil
function M.notify(msg, level)
  level = level or vim.log.levels.INFO
  local lib = try_require("lib.nvim.notify")
  if lib and type(lib.create) == "function" then
    local ok, notifier = pcall(lib.create, "[cascade]")
    if ok and type(notifier) == "table" and type(notifier.notify) == "function" then
      local notify_ok = pcall(notifier.notify, msg, level)
      if notify_ok then
        return
      end
    end
  end
  vim.notify(("[cascade] %s"):format(msg), level)
end

--- Cached `lib.nvim.logger` instance for cascade (`false` once probed absent,
--- so the check is never retried).
---@type table|false|nil
local _debug_logger = nil

--- Resolve (and cache) the `lib.nvim.logger` instance for cascade, or
--- `false` if unavailable.
---@return table|false
local function debug_logger()
  if _debug_logger ~= nil then
    return _debug_logger
  end
  local lib = try_require("lib.nvim.logger")
  if lib and type(lib.new) == "function" then
    local ok, inst = pcall(lib.new, { name = "cascade" })
    _debug_logger = (ok and type(inst) == "table") and inst or false
  else
    _debug_logger = false
  end
  return _debug_logger
end

--- Debug-log `msg` (+ optional structured `ctx`) at cascade's central
--- decision points (detect -> advance -> fallback), when `cascade.debug` is
--- enabled. Bridges to `lib.nvim.logger` (one cached "cascade" instance)
--- when available; falls back to `vim.notify` at DEBUG level otherwise --
--- there's no good native substitute for a structured logger, but debug
--- output should still be visible rather than silently dropped. A no-op
--- call (the common case, debug off) costs one boolean check.
---@param enabled boolean
---@param msg string
---@param ctx table|nil
---@return nil
function M.debug_log(enabled, msg, ctx)
  if not enabled then
    return
  end
  local logger = debug_logger()
  if logger then
    pcall(logger.debug, msg, ctx)
    return
  end
  local text = ctx and ("%s %s"):format(msg, vim.inspect(ctx)) or msg
  vim.notify(("[cascade] %s"):format(text), vim.log.levels.DEBUG)
end

--- Set a keymap. Uses `lib.nvim.map` if available, else `vim.keymap.set`.
---@param mode string|string[]
---@param lhs string
---@param rhs string|function
---@param opts table|nil
---@return nil
function M.map(mode, lhs, rhs, opts)
  opts = opts or {}
  local lib = try_require("lib.nvim.map")
  if type(lib) == "function" then
    local ok = pcall(lib, mode, lhs, rhs, opts)
    if ok then
      return
    end
  end
  vim.keymap.set(mode, lhs, rhs, opts)
end

--- Create an autocommand group. Returns the group id.
---@param name string
---@return integer
function M.augroup(name)
  local lib = try_require("lib.nvim.autocmd.augroup")
  if lib and type(lib.create) == "table" and type(lib.create.clear) == "function" then
    local ok, id = pcall(lib.create.clear, name)
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

--- Classify the capitalization of a token. Uses `lib.lua.strings.case` if
--- available, else a local fallback.
---@param s string
---@return "lower"|"upper"|"capital"|"mixed"
function M.case_shape(s)
  local lib = try_require("lib.lua.strings.case")
  if lib and type(lib.case_shape) == "function" then
    local ok, shape = pcall(lib.case_shape, s)
    if ok then
      return shape
    end
  end

  if s == "" then
    return "lower"
  end
  local first, rest = s:sub(1, 1), s:sub(2)
  if s == s:lower() then
    return "lower"
  end
  if s == s:upper() then
    return "upper"
  end
  if first == first:upper() and rest == rest:lower() then
    return "capital"
  end
  return "mixed"
end

--- Apply a case shape to a replacement token. Uses `lib.lua.strings.case`
--- if available, else a local fallback.
---@param repl string
---@param shape "lower"|"upper"|"capital"|"mixed"
---@return string
function M.apply_shape(repl, shape)
  local lib = try_require("lib.lua.strings.case")
  if lib and type(lib.apply_shape) == "function" then
    local ok, result = pcall(lib.apply_shape, repl, shape)
    if ok then
      return result
    end
  end

  if shape == "upper" then
    return repl:upper()
  elseif shape == "capital" then
    return repl:sub(1, 1):upper() .. repl:sub(2):lower()
  elseif shape == "mixed" then
    return repl
  end
  return repl:lower()
end

local ROMAN_STEPS = {
  { 1000, "M" }, { 900, "CM" }, { 500, "D" }, { 400, "CD" },
  { 100, "C" }, { 90, "XC" }, { 50, "L" }, { 40, "XL" },
  { 10, "X" }, { 9, "IX" }, { 5, "V" }, { 4, "IV" }, { 1, "I" },
}
local ROMAN_VALUE = { I = 1, V = 5, X = 10, L = 50, C = 100, D = 500, M = 1000 }

local function roman_to_roman_fallback(n)
  if type(n) ~= "number" or n < 1 or n > 3999 then
    return nil
  end
  local rem = math.floor(n)
  local out, k = {}, 0
  for i = 1, #ROMAN_STEPS do
    local v, sym = ROMAN_STEPS[i][1], ROMAN_STEPS[i][2]
    while rem >= v do
      k = k + 1
      out[k] = sym
      rem = rem - v
    end
  end
  return table.concat(out)
end

local function roman_to_int_fallback(s)
  if type(s) ~= "string" or s == "" then
    return nil
  end
  local up = s:upper()
  if not up:match("^[MDCLXVI]+$") then
    return nil
  end
  local total = 0
  for i = 1, #up do
    local cur = ROMAN_VALUE[up:sub(i, i)]
    local nxt = ROMAN_VALUE[up:sub(i + 1, i + 1)] or 0
    if cur < nxt then
      total = total - cur
    else
      total = total + cur
    end
  end
  if roman_to_roman_fallback(total) ~= up then
    return nil
  end
  return total
end

--- Convert an integer (1..3999) to an uppercase Roman numeral, or nil if out
--- of range. Uses `lib.lua.numeral.roman` if available, else a local
--- fallback.
---@param n integer
---@return string|nil
function M.roman_to_roman(n)
  local lib = try_require("lib.lua.numeral")
  if lib and lib.roman and type(lib.roman.to_roman) == "function" then
    local ok, result = pcall(lib.roman.to_roman, n)
    if ok then
      return result
    end
  end
  return roman_to_roman_fallback(n)
end

--- Convert a Roman numeral (any case) to an integer, or nil if invalid
--- (including non-canonical forms like "IIII"). Uses `lib.lua.numeral.roman`
--- if available, else a local fallback.
---@param s string
---@return integer|nil
function M.roman_to_int(s)
  local lib = try_require("lib.lua.numeral")
  if lib and lib.roman and type(lib.roman.to_int) == "function" then
    local ok, result = pcall(lib.roman.to_int, s)
    if ok then
      return result
    end
  end
  return roman_to_int_fallback(s)
end

local function alpha_to_int_fallback(s)
  if type(s) ~= "string" or not s:match("^%a+$") then
    return nil
  end
  local low = s:lower()
  local n = 0
  for i = 1, #low do
    n = n * 26 + (low:byte(i) - 96)
  end
  return n
end

local function alpha_to_alpha_fallback(n)
  if type(n) ~= "number" or n < 1 then
    return nil
  end
  n = math.floor(n)
  local rev, k = {}, 0
  while n > 0 do
    local r = (n - 1) % 26
    k = k + 1
    rev[k] = string.char(97 + r)
    n = math.floor((n - 1) / 26)
  end
  local out = {}
  for i = k, 1, -1 do
    out[k - i + 1] = rev[i]
  end
  return table.concat(out)
end

--- Convert an alphabetic ordinal (any case; a=1, z=26, aa=27, ...) to an
--- integer, or nil if invalid. Uses `lib.lua.numeral.alpha` if available,
--- else a local fallback.
---@param s string
---@return integer|nil
function M.alpha_to_int(s)
  local lib = try_require("lib.lua.numeral")
  if lib and lib.alpha and type(lib.alpha.to_int) == "function" then
    local ok, result = pcall(lib.alpha.to_int, s)
    if ok then
      return result
    end
  end
  return alpha_to_int_fallback(s)
end

--- Convert a positive integer to its lowercase alphabetic ordinal
--- (spreadsheet-style: 1=a, 26=z, 27=aa, ...). Uses `lib.lua.numeral.alpha`
--- if available, else a local fallback.
---@param n integer
---@return string|nil
function M.alpha_to_alpha(n)
  local lib = try_require("lib.lua.numeral")
  if lib and lib.alpha and type(lib.alpha.to_alpha) == "function" then
    local ok, result = pcall(lib.alpha.to_alpha, n)
    if ok then
      return result
    end
  end
  return alpha_to_alpha_fallback(n)
end

local _pending_dotrepeat_fn = nil

--- Stable operatorfunc dispatcher for the local dotrepeat_run fallback.
--- Reached from Vimscript via v:lua; must keep this exact name/path.
function M.dotrepeat_invoke()
  local fn = _pending_dotrepeat_fn
  if fn then pcall(fn) end
end

--- Also register with the classic vim-repeat plugin (tpope/vim-repeat), if
--- installed, alongside the operatorfunc/g@l trick below. Purely optional
--- interop, never a dependency: vim-repeat's own `.` falls back to Neovim's
--- native last-change repeat when nothing was explicitly `repeat#set`, and
--- that native repeat already correctly replays the `g@l` this triggers --
--- this just makes it explicit for anything that specifically watches
--- vim-repeat's state instead of Neovim's native repeat.
---
--- No `exists("*repeat#set")` precheck: `repeat#set` is an autoload
--- function, and Neovim's `exists()` only reflects functions *already*
--- sourced -- vim-repeat's own plugin/repeat.vim only registers a mapping
--- that *references* the name, so on a fresh session (before the user has
--- ever pressed `.`) the precheck would report "absent" even when the
--- plugin is genuinely installed and would load correctly on first call.
--- Calling straight through (wrapped in `pcall`) lets Neovim's autoload
--- mechanism do the real detection: it either finds and sources
--- `autoload/repeat.vim`, or `pcall` swallows the "unknown function" error
--- exactly as if the precheck had failed.
local function set_vim_repeat()
  pcall(vim.fn["repeat#set"], "g@l")
end

--- Run `fn` via native `.`-repeat (operatorfunc + `g@l`). Uses
--- `lib.nvim.dotrepeat` if available, else a local fallback with the same
--- mechanism (own stable dispatcher). Either way, also calls `repeat#set`
--- when vim-repeat is installed (see `set_vim_repeat`).
---@param fn fun()
function M.dotrepeat_run(fn)
  local lib = try_require("lib.nvim.dotrepeat")
  if lib and type(lib.run) == "function" then
    local ok = pcall(lib.run, fn)
    if ok then
      set_vim_repeat()
      return
    end
  end
  _pending_dotrepeat_fn = fn
  vim.o.operatorfunc = "v:lua.require'cascade.util.lib'.dotrepeat_invoke"
  vim.api.nvim_feedkeys("g@l", "n", false)
  set_vim_repeat()
end

--- No bridge to `lib.nvim` here, by design: the closest module is
--- `lib.nvim.buf_win_tab.selection`, but its shape doesn't match what
--- `keep_lines`/`keep_chars` need. `get_visual_selection()` returns
--- 1-based rows/cols plus the selected text, not the 0-based row-only or
--- row+col bounds these functions traffic in; and `reselect_visual()`
--- takes no bounds and re-enters Visual via `normal! gv`, which is exactly
--- the unreliable-mid-selection behavior `reselect_lines_fallback`/
--- `reselect_chars_fallback` exist to avoid (see their doc comments). An
--- explicit-bounds reselect would need to be added to `lib.nvim` first;
--- until then these stay standalone-only.

--- 0-based inclusive row range of the current Visual selection.
---@return integer srow, integer erow
function M.lines()
  return lines_fallback()
end

--- Restore a linewise (`V`) selection over `[srow, erow]` (0-based
--- inclusive).
---@param srow integer
---@param erow integer
---@return nil
function M.reselect_lines(srow, erow)
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
--- (No `lib.nvim` bridge — see the note above `M.lines`.)
---@return integer|nil row, integer|nil scol, integer|nil ecol
function M.chars()
  return chars_fallback()
end

--- Restore a charwise (`v`) selection spanning byte columns `[scol, ecol]`
--- (0-based inclusive) on `row`. (No `lib.nvim` bridge — see the note above
--- `M.lines`.)
---@param row integer
---@param scol integer
---@param ecol integer
---@return nil
function M.reselect_chars(row, scol, ecol)
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

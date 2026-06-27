---@module 'cascade'
---@brief Public facade for cascade.nvim: setup + the action surface.
---@description
--- One entry point that wires configuration, exposes every user-facing action
--- (consumed by `<Plug>` mappings in `cascade.keymaps`), and routes the
--- dot-repeatable actions through the shared operatorfunc helper. Actions build a
--- single `CascadeContext` per call and fall back to native keys when no
--- structured context applies, per the detect -> advance -> fallback pattern.

local config = require("cascade.config")
local Context = require("cascade.core.context")
local dispatch = require("cascade.dispatch")
local dotrepeat = require("cascade.util.dotrepeat")

local continue = require("cascade.lists.continue")
local checkbox = require("cascade.lists.checkbox")
local cycle_type = require("cascade.lists.cycle_type")
local indent_mod = require("cascade.lists.indent")
local renumber = require("cascade.lists.renumber")
local transform = require("cascade.lists.transform")
local word_cycle = require("cascade.cycle.word_cycle")

local M = {}

-- ---------- gating helpers ----------

--- Whether `ft` is in `fts` (nil `fts` means "every filetype").
---@param fts string[]|nil
---@param ft string
---@return boolean
local function ft_in(fts, ft)
  if fts == nil then
    return true
  end
  for i = 1, #fts do
    if fts[i] == ft then
      return true
    end
  end
  return false
end

--- Feed a native key without remapping.
---@param lhs string
---@return nil
local function feed(lhs)
  vim.api.nvim_feedkeys(vim.keycode(lhs), "n", false)
end

--- Whether the list domain is active for the current buffer.
---@param ctx CascadeContext
---@return boolean
local function lists_active(ctx)
  local opts = config.get("lists")
  return opts.enable and Context.writable(ctx.bufnr) and ft_in(opts.filetypes, ctx.ft)
end

-- ---------- list continuation (with native fallback) ----------

--- `<CR>` in insert mode: continue the list or fall back to a newline.
---@return nil
function M.cr()
  local ctx = Context.new()
  local opts = config.get("lists")
  if lists_active(ctx) and continue.cr(ctx, opts) then
    return
  end
  feed("<CR>")
end

--- `o`: open a continued item below, or fall back to native `o`.
---@return nil
function M.o()
  local ctx = Context.new()
  local opts = config.get("lists")
  if lists_active(ctx) and continue.o(ctx, opts) then
    return
  end
  feed("o")
end

--- `O`: open a continued item above, or fall back to native `O`.
---@return nil
function M.O()
  local ctx = Context.new()
  local opts = config.get("lists")
  if lists_active(ctx) and continue.O(ctx, opts) then
    return
  end
  feed("O")
end

--- Indent the current list line (no-op off a list).
---@return nil
function M.indent()
  local ctx = Context.new()
  local opts = config.get("lists")
  if lists_active(ctx) then
    indent_mod.indent(ctx, opts)
  end
end

--- Dedent the current list line (no-op off a list).
---@return nil
function M.dedent()
  local ctx = Context.new()
  local opts = config.get("lists")
  if lists_active(ctx) then
    indent_mod.dedent(ctx, opts)
  end
end

--- Renumber the ordered block at the cursor.
---@return nil
function M.renumber()
  local ctx = Context.new()
  local opts = config.get("lists")
  if lists_active(ctx) then
    pcall(renumber.run, ctx.bufnr, ctx.row0, opts)
  end
end

-- ---------- dot-repeatable actions ----------

--- Toggle/cycle the checkbox under the cursor.
local checkbox_work = function()
  local ctx = Context.new()
  local opts = config.get("lists")
  if lists_active(ctx) then
    dispatch.try({ function(c)
      return checkbox.toggle(c, opts)
    end }, ctx)
  end
end

--- Cycle the list marker type at the cursor.
---@param dir integer
---@return fun()
local function cycle_type_work(dir)
  return function()
    local ctx = Context.new()
    local opts = config.get("lists")
    if lists_active(ctx) then
      cycle_type.cycle(ctx, opts, dir)
    end
  end
end

--- Cycle the word under the cursor; fall back to native increment/decrement.
---@param dir integer
---@param fallback string
---@return fun()
local function cycle_word_work(dir, fallback)
  return function()
    local opts = config.get("cycle")
    if not opts.enable then
      feed(fallback)
      return
    end
    local ctx = Context.new()
    if not Context.writable(ctx.bufnr) or not ft_in(opts.filetypes, ctx.ft) then
      feed(fallback)
      return
    end
    if not word_cycle.cycle(ctx, opts, dir) then
      if opts.number_fallback then
        feed(fallback)
      end
    end
  end
end

M.toggle_checkbox = dotrepeat.repeatable("checkbox", checkbox_work)
M.cycle_type_next = dotrepeat.repeatable("cycle_type_next", cycle_type_work(1))
M.cycle_type_prev = dotrepeat.repeatable("cycle_type_prev", cycle_type_work(-1))
M.cycle_word_next = dotrepeat.repeatable("cycle_word_next", cycle_word_work(1, "<C-a>"))
M.cycle_word_prev = dotrepeat.repeatable("cycle_word_prev", cycle_word_work(-1, "<C-x>"))

-- ---------- block / visual transforms ----------

--- 0-based inclusive line range of the current visual selection.
---@return integer srow, integer erow
local function visual_range()
  local a = vim.fn.line("v") - 1
  local b = vim.fn.line(".") - 1
  if a > b then
    a, b = b, a
  end
  return a, b
end

--- Resolve the block range at the cursor for a transform.
---@param ctx CascadeContext
---@return integer|nil srow, integer|nil erow
local function block_range(ctx)
  local opts = config.get("lists")
  return transform.block_range(ctx.bufnr, ctx.row0, opts)
end

--- Normal-mode block transform worker.
---@param fn fun(bufnr: integer, s: integer, e: integer, dir: integer, opts: CascadeListOpts): boolean
---@param dir integer
---@return fun()
local function block_work(fn, dir)
  return function()
    local ctx = Context.new()
    if not lists_active(ctx) then
      return
    end
    local s, e = block_range(ctx)
    if s and e then
      fn(ctx.bufnr, s, e, dir, config.get("lists"))
    end
  end
end

--- Visual-mode range transform.
---@param fn fun(bufnr: integer, s: integer, e: integer, dir: integer, opts: CascadeListOpts): boolean
---@param dir integer
---@return fun()
local function visual_work(fn, dir)
  return function()
    local bufnr = vim.api.nvim_get_current_buf()
    local opts = config.get("lists")
    if not (opts.enable and Context.writable(bufnr) and ft_in(opts.filetypes, vim.bo[bufnr].filetype)) then
      return
    end
    local s, e = visual_range()
    fn(bufnr, s, e, dir, opts)
    feed("<Esc>")
  end
end

M.rotate_form_next = dotrepeat.repeatable("rotate_next", block_work(transform.rotate, 1))
M.rotate_form_prev = dotrepeat.repeatable("rotate_prev", block_work(transform.rotate, -1))
M.rotate_form_next_visual = visual_work(transform.rotate, 1)
M.rotate_form_prev_visual = visual_work(transform.rotate, -1)

M.sort = dotrepeat.repeatable("sort", block_work(transform.sort, 1))
M.sort_visual = visual_work(transform.sort, 1)

M.reverse = dotrepeat.repeatable("reverse", block_work(transform.reverse, 1))
M.reverse_visual = visual_work(transform.reverse, 1)

M.strip_checkbox = dotrepeat.repeatable("strip", block_work(transform.strip, 1))
M.strip_checkbox_visual = visual_work(transform.strip, 1)

--- Run a block transform from a `:command` (range-aware). Used by user commands.
---@param fn fun(bufnr: integer, s: integer, e: integer, dir: integer, opts: CascadeListOpts): boolean
---@param cmd table # The nvim user-command argument table.
---@param dir integer
---@return nil
function M.run_command(fn, cmd, dir)
  local opts = config.get("lists")
  local bufnr = vim.api.nvim_get_current_buf()
  if not (opts.enable and Context.writable(bufnr)) then
    return
  end
  local s, e
  if cmd.range and cmd.range > 0 then
    s, e = cmd.line1 - 1, cmd.line2 - 1
  else
    s, e = transform.block_range(bufnr, vim.api.nvim_win_get_cursor(0)[1] - 1, opts)
  end
  if s and e then
    fn(bufnr, s, e, dir, opts)
  end
end

-- Expose the transform functions so user commands can reference them by name.
M._transform = transform

-- ---------- setup ----------

--- Configure cascade.nvim and (optionally) bind the preset keymaps.
---@param opts CascadeConfig|nil
---@return nil
function M.setup(opts)
  config.setup(opts)
  require("cascade.keymaps").setup(config.options)
end

return M

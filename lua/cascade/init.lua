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
local move_mod = require("cascade.lists.move")
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

--- Whether a named list feature is enabled (missing entry = enabled).
---@param name string
---@return boolean
local function lf(name)
  local f = config.get("lists").features
  return type(f) ~= "table" or f[name] ~= false
end

--- Whether a named cycle feature is enabled (missing entry = enabled).
---@param name string
---@return boolean
local function cf(name)
  local f = config.get("cycle").features
  return type(f) ~= "table" or f[name] ~= false
end

-- ---------- list continuation (with native fallback) ----------

--- `<CR>` in insert mode: continue the list or fall back to a newline.
---@return nil
function M.cr()
  local ctx = Context.new()
  local opts = config.get("lists")
  if lists_active(ctx) and lf("continue") and continue.cr(ctx, opts) then
    return
  end
  feed("<CR>")
end

--- `o`: open a continued item below, or fall back to native `o`.
---@return nil
function M.o()
  local ctx = Context.new()
  local opts = config.get("lists")
  if lists_active(ctx) and lf("continue") and continue.o(ctx, opts) then
    return
  end
  feed("o")
end

--- `O`: open a continued item above, or fall back to native `O`.
---@return nil
function M.O()
  local ctx = Context.new()
  local opts = config.get("lists")
  if lists_active(ctx) and lf("continue") and continue.O(ctx, opts) then
    return
  end
  feed("O")
end

--- Indent the current list line (no-op off a list).
---@return nil
function M.indent()
  local count = vim.v.count1
  local ctx = Context.new()
  local opts = config.get("lists")
  if lists_active(ctx) and lf("indent") and indent_mod.shift_line(ctx, opts, count, 1) then
    return
  end
  feed(string.rep(">>", count))
end

--- Dedent the current line; list-aware renumber, else native `<<`.
---@return nil
function M.dedent()
  local count = vim.v.count1
  local ctx = Context.new()
  local opts = config.get("lists")
  if lists_active(ctx) and lf("indent") and indent_mod.shift_line(ctx, opts, count, -1) then
    return
  end
  feed(string.rep("<<", count))
end

--- Indent the visual selection; renumber list blocks; reselect.
---@return nil
function M.indent_visual()
  M._shift_visual(1)
end

--- Dedent the visual selection; renumber list blocks; reselect.
---@return nil
function M.dedent_visual()
  M._shift_visual(-1)
end

--- Renumber the ordered block at the cursor (manual; ignores the trigger
--- config — always runs, indent-level aware).
---@return nil
function M.renumber()
  local ctx = Context.new()
  local opts = config.get("lists")
  if not lists_active(ctx) then
    return
  end
  local s, e = transform.block_range(ctx.bufnr, ctx.row0, opts)
  if s and e then
    pcall(renumber.tree, ctx.bufnr, s, e, opts)
  end
end

-- ---------- dot-repeatable actions ----------

--- Toggle/cycle the checkbox under the cursor.
local checkbox_work = function()
  local ctx = Context.new()
  local opts = config.get("lists")
  if lists_active(ctx) and lf("checkbox") then
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
    if lists_active(ctx) and lf("cycle_type") then
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
    if not opts.enable or not cf("word") then
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
---@param feature string # list feature this worker belongs to
---@return fun()
local function block_work(fn, dir, feature)
  return function()
    local ctx = Context.new()
    if not lists_active(ctx) or not lf(feature) then
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
---@param feature string # list feature this worker belongs to
---@return fun()
local function visual_work(fn, dir, feature)
  return function()
    local bufnr = vim.api.nvim_get_current_buf()
    local opts = config.get("lists")
    if not (opts.enable and lf(feature) and Context.writable(bufnr) and ft_in(opts.filetypes, vim.bo[bufnr].filetype)) then
      return
    end
    local s, e = visual_range()
    fn(bufnr, s, e, dir, opts)
    feed("<Esc>")
  end
end

M.rotate_form_next = dotrepeat.repeatable("rotate_next", block_work(transform.rotate, 1, "rotate"))
M.rotate_form_prev = dotrepeat.repeatable("rotate_prev", block_work(transform.rotate, -1, "rotate"))
M.rotate_form_next_visual = visual_work(transform.rotate, 1, "rotate")
M.rotate_form_prev_visual = visual_work(transform.rotate, -1, "rotate")

M.sort = dotrepeat.repeatable("sort", block_work(transform.sort, 1, "sort"))
M.sort_visual = visual_work(transform.sort, 1, "sort")

M.reverse = dotrepeat.repeatable("reverse", block_work(transform.reverse, 1, "reverse"))
M.reverse_visual = visual_work(transform.reverse, 1, "reverse")

M.strip_checkbox = dotrepeat.repeatable("strip", block_work(transform.strip, 1, "strip"))
M.strip_checkbox_visual = visual_work(transform.strip, 1, "strip")

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

--- Shift the visual selection by one direction, renumbering list blocks, and
--- reselect with `gv`. Works in any filetype (renumber only in list filetypes).
---@param dir integer # 1 indent, -1 dedent.
---@return nil
function M._shift_visual(dir)
  local count = vim.v.count1
  local bufnr = vim.api.nvim_get_current_buf()
  if not Context.writable(bufnr) then
    feed("gv")
    return
  end
  local opts = config.get("lists")
  local renumber_ok = opts.enable and lf("indent") and ft_in(opts.filetypes, vim.bo[bufnr].filetype)
  local s, e = visual_range()
  indent_mod.shift_range(bufnr, s, e, dir, count, opts, renumber_ok)
  feed("gv")
end

--- Run an indent/dedent from a `:command` (range- and count-aware).
---@param cmd table # The nvim user-command argument table.
---@param dir integer # 1 indent, -1 dedent.
---@return nil
function M.run_indent_command(cmd, dir)
  local bufnr = vim.api.nvim_get_current_buf()
  if not Context.writable(bufnr) then
    return
  end
  local count = tonumber(cmd.args) or 1
  if count < 1 then
    count = 1
  end
  local s, e
  if cmd.range and cmd.range > 0 then
    s, e = cmd.line1 - 1, cmd.line2 - 1
  else
    local r = vim.api.nvim_win_get_cursor(0)[1] - 1
    s, e = r, r
  end
  local opts = config.get("lists")
  local renumber_ok = opts.enable and lf("indent") and ft_in(opts.filetypes, vim.bo[bufnr].filetype)
  indent_mod.shift_range(bufnr, s, e, dir, count, opts, renumber_ok)
end

-- ---------- move lines ----------

--- Move the current line up; reindent; renumber list block.
---@return nil
function M.move_up()
  M._move(-1)
end

--- Move the current line down; reindent; renumber list block.
---@return nil
function M.move_down()
  M._move(1)
end

--- Internal: normal-mode move.
---@param dir integer # -1 up, 1 down.
---@return nil
function M._move(dir)
  local bufnr = vim.api.nvim_get_current_buf()
  if not Context.writable(bufnr) or not lf("move") then
    return
  end
  move_mod.line(bufnr, dir, config.get("lists"))
end

--- Move the visual selection up.
---@return nil
function M.move_up_visual()
  M._move_visual(-1)
end

--- Move the visual selection down.
---@return nil
function M.move_down_visual()
  M._move_visual(1)
end

--- Internal: visual-mode move.
---@param dir integer # -1 up, 1 down.
---@return nil
function M._move_visual(dir)
  local bufnr = vim.api.nvim_get_current_buf()
  if not Context.writable(bufnr) or not lf("move") then
    feed("gv")
    return
  end
  local s, e = visual_range()
  if not move_mod.selection(bufnr, s, e, dir, config.get("lists")) then
    feed("gv")
  end
end

-- Expose the transform functions so user commands can reference them by name.
M._transform = transform

-- ---------- setup ----------

--- Register the BufWritePre renumber autocmd when "save" is a configured
--- trigger. Idempotent: the augroup is cleared on every setup() call.
---@return nil
local function setup_save_renumber()
  local group = vim.api.nvim_create_augroup("cascade_renumber_save", { clear = true })
  local lists = config.get("lists")
  if not (lists.enable and renumber.at(lists, "save")) then
    return
  end
  vim.api.nvim_create_autocmd("BufWritePre", {
    group = group,
    pattern = "*",
    desc = "cascade: renumber lists on save",
    callback = function(args)
      local opts = config.get("lists")
      if not (opts.enable and renumber.at(opts, "save")) then
        return
      end
      if not Context.writable(args.buf) or not ft_in(opts.filetypes, vim.bo[args.buf].filetype) then
        return
      end
      pcall(renumber.all, args.buf, opts)
    end,
  })
end

--- Configure cascade.nvim and (optionally) bind the preset keymaps.
---@param opts CascadeConfig|nil
---@return nil
function M.setup(opts)
  config.setup(opts)
  require("cascade.keymaps").setup(config.options)
  setup_save_renumber()
end

return M

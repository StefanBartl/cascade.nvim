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

-- ---------- setup ----------

--- Configure cascade.nvim and (optionally) bind the preset keymaps.
---@param opts CascadeConfig|nil
---@return nil
function M.setup(opts)
  config.setup(opts)
  require("cascade.keymaps").setup(config.options)
end

return M

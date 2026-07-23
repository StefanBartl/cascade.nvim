---@module 'cascade'
---@brief Public facade for cascade.nvim: setup + the action surface.
---@description
--- One entry point that wires configuration, exposes every user-facing action
--- (bound directly onto keys by `cascade.bindings`), and routes the
--- dot-repeatable actions through the shared operatorfunc helper. Actions build a
--- single `CascadeContext` per call and fall back to native keys when no
--- structured context applies, per the detect -> advance -> fallback pattern.

local config = require("cascade.config")
local Context = require("cascade.core.context")
local dispatch = require("cascade.dispatch")
local dotrepeat = require("cascade.util.dotrepeat")
local lib = require("cascade.util.lib")

local continue = require("cascade.lists.continue")
local checkbox = require("cascade.lists.checkbox")
local quick_toggle = require("cascade.lists.quick_toggle")
local cycle_type = require("cascade.lists.cycle_type")
local indent_mod = require("cascade.lists.indent")
local move_mod = require("cascade.lists.move")
local renumber = require("cascade.lists.renumber")
local transform = require("cascade.lists.transform")
local word_cycle = require("cascade.cycle.word_cycle")
local token = require("cascade.cycle.token")
local date = require("cascade.cycle.date")
local treesitter = require("cascade.core.treesitter")
local transpose_char = require("cascade.transpose.char")

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

--- Whether the list domain is active for the current buffer/cursor position.
--- With `lists.precision = "treesitter"`, also false inside a configured
--- "skip" node (e.g. a markdown fenced code block) -- see
--- `cascade.core.treesitter`. Only gates single-cursor-position actions
--- (continuation, toggles, single-line indent, ...); range/whole-buffer
--- operations (visual shifts, `:Cascade` commands, save-time renumber-all)
--- don't check per-line, since "inside a skip node" isn't well-defined for
--- an arbitrary range.
---@param ctx CascadeContext
---@return boolean
local function lists_active(ctx)
  local opts = config.get("lists")
  local debug = config.get("debug") == true

  if not opts.enable then
    lib.debug_log(debug, "lists_active: lists.enable is false")
    return false
  end
  if not Context.writable(ctx.bufnr) then
    lib.debug_log(debug, "lists_active: buffer not writable", { bufnr = ctx.bufnr })
    return false
  end
  if not ft_in(opts.filetypes, ctx.ft) then
    lib.debug_log(debug, "lists_active: filetype not in lists.filetypes", { ft = ctx.ft })
    return false
  end
  if treesitter.in_skip_node(ctx.bufnr, ctx.row0, ctx.col0, ctx.ft, opts) then
    lib.debug_log(debug, "lists_active: cursor inside a treesitter skip node", { ft = ctx.ft, row = ctx.row0 })
    return false
  end
  return true
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

--- Whether a named transpose feature is enabled (missing entry = enabled).
---@param name string
---@return boolean
local function xf(name)
  local f = config.get("transpose").features
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
    pcall(renumber.tree, ctx.bufnr, s, e, opts, true)
  end
end

-- ---------- dot-repeatable actions ----------

--- Toggle/cycle the checkbox under the cursor.
local checkbox_work = function()
  local ctx = Context.new()
  local opts = config.get("lists")
  if lists_active(ctx) and lf("checkbox") then
    dispatch.try({
      function(c)
        return checkbox.toggle(c, opts)
      end,
    }, ctx)
  end
end

--- Toggle a plain unordered bullet on the cursor line; works without an
--- existing marker (unlike `checkbox`/`cycle_type`, which only ever advance
--- one). Shared by the `-` and `*` variants.
---@param single fun(ctx: CascadeContext, opts: CascadeListOpts): boolean
---@return fun()
local function bullet_toggle_work(single)
  return function()
    local ctx = Context.new()
    local opts = config.get("lists")
    if lists_active(ctx) and lf("bullet_toggle") then
      dispatch.try({
        function(c)
          return single(c, opts)
        end,
      }, ctx)
    end
  end
end

--- Toggle a "1." numbered marker on the cursor line; works without an
--- existing marker, and renumbers against its siblings once inserted.
local number_toggle_work = function()
  local ctx = Context.new()
  local opts = config.get("lists")
  if lists_active(ctx) and lf("number_toggle") then
    dispatch.try({
      function(c)
        return quick_toggle.number(c, opts)
      end,
    }, ctx)
  end
end

--- Cycle a "- [ ]" checkbox on the cursor line; creates it from scratch if
--- needed and removes it again after the last configured state.
local checkbox_toggle_work = function()
  local ctx = Context.new()
  local opts = config.get("lists")
  if lists_active(ctx) and lf("checkbox_toggle") then
    dispatch.try({
      function(c)
        return quick_toggle.checkbox(c, opts)
      end,
    }, ctx)
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

--- Cycle the word under the cursor. On an ISO date (`YYYY-MM-DD`), step the
--- year/month/day segment under the cursor with calendar-aware rollover. On
--- a plain numeric token, fall back to the real native increment/decrement
--- (`<C-a>`/`<C-x>`) regardless of which key triggered this; on anything else
--- (no match at all), fall back to the triggering key's own native meaning,
--- so e.g. `+`/`-` still move a line when the cursor isn't on a cyclable
--- word, a date, or a number.
---@param dir integer
---@param number_key string # native key that increments/decrements numbers.
---@param own_key string # the key this action is bound to.
---@return fun()
local function cycle_word_work(dir, number_key, own_key)
  return function()
    local opts = config.get("cycle")
    if not opts.enable then
      feed(own_key)
      return
    end
    local ctx = Context.new()
    if not Context.writable(ctx.bufnr) or not ft_in(opts.filetypes, ctx.ft) then
      feed(own_key)
      return
    end

    if cf("date") then
      local s0, e0, repl = date.step(ctx.line, ctx.col0, dir)
      if s0 then
        vim.api.nvim_buf_set_text(ctx.bufnr, ctx.row0, s0, ctx.row0, e0, { repl })
        return
      end
    end

    if cf("word") and word_cycle.cycle(ctx, opts, dir) then
      return
    end
    local _, _, text = token.span(ctx.line, ctx.col0)
    if opts.number_fallback and token.is_numeric(text) then
      feed(number_key)
    else
      feed(own_key)
    end
  end
end

--- Show an interactive picker over every entry in the cursor's cycle group
--- (word or operator), replacing it with whichever the user picks. Silent
--- no-op when the cursor isn't on a cyclable token -- there's no "own key"
--- native meaning to fall back to for an otherwise-unbound leader mapping.
---@return nil
function M.cycle_pick()
  local opts = config.get("cycle")
  if not opts.enable or not cf("word") then
    return
  end
  local ctx = Context.new()
  if not Context.writable(ctx.bufnr) or not ft_in(opts.filetypes, ctx.ft) then
    return
  end
  word_cycle.pick(ctx, opts)
end

M.toggle_checkbox = dotrepeat.repeatable("checkbox", checkbox_work)
M.bullet_toggle = dotrepeat.repeatable("bullet_toggle", bullet_toggle_work(quick_toggle.bullet))
M.star_toggle = dotrepeat.repeatable("star_toggle", bullet_toggle_work(quick_toggle.star))
M.number_toggle = dotrepeat.repeatable("number_toggle", number_toggle_work)
M.checkbox_toggle = dotrepeat.repeatable("checkbox_toggle", checkbox_toggle_work)
M.cycle_type_next = dotrepeat.repeatable("cycle_type_next", cycle_type_work(1))
M.cycle_type_prev = dotrepeat.repeatable("cycle_type_prev", cycle_type_work(-1))
M.cycle_word_next = dotrepeat.repeatable("cycle_word_next", cycle_word_work(1, "<C-a>", "<C-y>"))
M.cycle_word_prev = dotrepeat.repeatable("cycle_word_prev", cycle_word_work(-1, "<C-x>", "<C-x>"))
M.increment = dotrepeat.repeatable("increment", cycle_word_work(1, "<C-a>", "+"))
M.decrement = dotrepeat.repeatable("decrement", cycle_word_work(-1, "<C-x>", "-"))

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

--- Visual-mode range transform. Keeps the same rows selected afterwards
--- (see `cascade.util.lib.keep_lines`) instead of dropping the selection.
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
    lib.keep_lines(function(s, e)
      fn(bufnr, s, e, dir, opts)
    end)
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

-- Visual variants of the quick toggles: apply independently to every
-- non-blank line in the selection (each line keeps deciding its own fate).
M.bullet_toggle_visual = visual_work(quick_toggle.bullet_range, 1, "bullet_toggle")
M.star_toggle_visual = visual_work(quick_toggle.star_range, 1, "bullet_toggle")
M.number_toggle_visual = visual_work(quick_toggle.number_range, 1, "number_toggle")
M.checkbox_toggle_visual = visual_work(quick_toggle.checkbox_range, 1, "checkbox_toggle")

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

--- Run `:Cascade renumber` from a `:command` (range-aware; `scope == "all"`
--- sweeps every list block in the buffer instead of just the current one).
---@param cmd table # The nvim user-command argument table.
---@param scope string|nil # "all", or nil/"block" for the range/cursor block.
---@return nil
function M.run_renumber_command(cmd, scope)
  local opts = config.get("lists")
  local bufnr = vim.api.nvim_get_current_buf()
  if not (opts.enable and Context.writable(bufnr)) then
    return
  end
  if scope == "all" then
    pcall(renumber.all, bufnr, opts)
    return
  end
  local s, e
  if cmd.range and cmd.range > 0 then
    s, e = cmd.line1 - 1, cmd.line2 - 1
  else
    s, e = transform.block_range(bufnr, vim.api.nvim_win_get_cursor(0)[1] - 1, opts)
  end
  if s and e then
    pcall(renumber.tree, bufnr, s, e, opts, true)
  end
end

--- Shift the visual selection by one direction, renumbering list blocks, and
--- reselect the shifted lines (see `cascade.util.lib.keep_lines`; shifting
--- never changes the line count, so the same rows still address them).
--- Works in any filetype (renumber only in list filetypes).
---@param dir integer # 1 indent, -1 dedent.
---@return nil
function M._shift_visual(dir)
  local count = vim.v.count1
  local bufnr = vim.api.nvim_get_current_buf()
  lib.keep_lines(function(s, e)
    if Context.writable(bufnr) then
      local opts = config.get("lists")
      local renumber_ok = opts.enable and lf("indent") and ft_in(opts.filetypes, vim.bo[bufnr].filetype)
      indent_mod.shift_range(bufnr, s, e, dir, count, opts, renumber_ok)
    end
  end)
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

-- ---------- transpose (swap char / selection with a neighbor) ----------

--- Swap the char under the cursor with its right (`dir = 1`) or left
--- (`dir = -1`) neighbor; no-op at the line boundary or when disabled.
---@param dir integer
---@return fun()
local function swap_work(dir)
  return function()
    local bufnr = vim.api.nvim_get_current_buf()
    local opts = config.get("transpose")
    if not (opts.enable and xf("char") and Context.writable(bufnr)) then
      return
    end
    transpose_char.char(Context.new(bufnr), dir)
  end
end

M.swap_right = dotrepeat.repeatable("swap_right", swap_work(1))
M.swap_left = dotrepeat.repeatable("swap_left", swap_work(-1))

--- Swap the visual selection with its right (`dir = 1`) or left (`dir = -1`)
--- neighbor char, keeping the swapped text itself selected afterwards. The
--- neighbor moves into the selection's old slot, so the selected text
--- shifts by the neighbor's byte width — reselect the *new* bounds
--- `transpose_char.selection` returns, not the original ones (unlike
--- `keep_chars`, which assumes the selected span never moves). No-op across
--- multiple lines, at the line boundary, or when disabled — the selection
--- is restored via `gv` (matching `_move_visual`'s convention) in those
--- cases.
---@param dir integer
---@return nil
function M._swap_visual(dir)
  local bufnr = vim.api.nvim_get_current_buf()
  local opts = config.get("transpose")
  if not (opts.enable and xf("char") and Context.writable(bufnr)) then
    feed("gv")
    return
  end
  local row, scol, ecol = lib.chars()
  if not row then
    feed("gv")
    return
  end
  local changed, new_scol, new_ecol = transpose_char.selection(bufnr, row, scol, ecol, dir)
  if changed then
    lib.reselect_chars(row, new_scol, new_ecol)
  else
    feed("gv")
  end
end

--- Swap the visual selection with its right neighbor char.
---@return nil
function M.swap_right_visual()
  M._swap_visual(1)
end

--- Swap the visual selection with its left neighbor char.
---@return nil
function M.swap_left_visual()
  M._swap_visual(-1)
end

-- Expose the transform functions so user commands can reference them by name.
M._transform = transform

-- ---------- setup ----------

--- Configure cascade.nvim and wire up every binding (see `cascade.bindings`).
---@param opts CascadeConfig|nil
---@return nil
function M.setup(opts)
  config.setup(opts)
  require("cascade.bindings").setup(config.options)
end

return M

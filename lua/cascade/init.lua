---@module 'cascade'
--- Public facade for cascade.nvim: setup + the action surface.
---
--- One entry point that wires configuration, exposes every user-facing action
--- (bound directly onto keys by `cascade.bindings`), and routes the
--- dot-repeatable actions through the shared operatorfunc helper. Actions build a
--- single `CascadeContext` per call and fall back to native keys when no
--- structured context applies, per the detect -> advance -> fallback pattern.

local config = require("cascade.config")
local notify = require("lib.nvim.notify").create("[cascade]")
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
local sequence = require("cascade.sequence.renumber")
local transpose_char = require("cascade.transpose.char")
local transpose_word = require("cascade.transpose.word")

local M = {}

-- ---------- gating helpers ----------

---@internal
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

---@internal
--- Feed a native key without remapping.
---@param lhs string
---@return nil
local function feed(lhs)
  vim.api.nvim_feedkeys(vim.keycode(lhs), "n", false)
end

---@internal
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

---@internal
--- Whether a named list feature is enabled (missing entry = enabled).
---@param name string
---@return boolean
local function lf(name)
  local f = config.get("lists").features
  return type(f) ~= "table" or f[name] ~= false
end

---@internal
--- Whether a named cycle feature is enabled (missing entry = enabled).
---@param name string
---@return boolean
local function cf(name)
  local f = config.get("cycle").features
  return type(f) ~= "table" or f[name] ~= false
end

---@internal
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

--- Escape hatch for `M.cr`: always a plain newline, list continuation skipped.
---@return nil
function M.cr_literal()
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

---@internal
--- Indent/dedent list lines starting at the cursor. With no count (or
--- count=1), shifts the current line (plus its subtree — nested children or
--- wrapped continuation text) by one level, preserving the cursor — same as
--- before. With count > 1, the count means "how many consecutive lines"
--- instead: shifts that many lines, starting at the cursor, by one level
--- each. Shifting one line by N *levels* moved to `<leader><A-Right>` /
--- `<leader><A-Left>` (see `indent_levels_work`).
---@param dir integer # 1 indent, -1 dedent.
---@param native string # native fallback key, repeated `count` times.
---@return fun()
local function indent_lines_work(dir, native)
  return function()
    local count = vim.v.count1
    local ctx = Context.new()
    local opts = config.get("lists")
    if lists_active(ctx) and lf("indent") then
      if count > 1 then
        local total = vim.api.nvim_buf_line_count(ctx.bufnr)
        local erow = math.min(ctx.row0 + count - 1, total - 1)
        indent_mod.shift_range(ctx.bufnr, ctx.row0, erow, dir, 1, opts, true)
        return
      end
      if indent_mod.shift_line(ctx, opts, 1, dir) then
        return
      end
    end
    feed(string.rep(native, count))
  end
end

---@internal
--- Indent/dedent the current line by `count` LEVELS instead of `count`
--- lines — the `<leader>`-prefixed variant preserving the old count meaning,
--- since `M.indent`/`M.dedent`'s own count now means "how many lines" (see
--- `indent_lines_work`). Invoke as `2<leader><A-Right>`.
---@param dir integer
---@param native string
---@return fun()
local function indent_levels_work(dir, native)
  return function()
    local count = vim.v.count1
    local ctx = Context.new()
    local opts = config.get("lists")
    if lists_active(ctx) and lf("indent") and indent_mod.shift_line(ctx, opts, count, dir) then
      return
    end
    feed(string.rep(native, count))
  end
end

M.indent = indent_lines_work(1, ">>")
M.dedent = indent_lines_work(-1, "<<")
M.indent_levels = indent_levels_work(1, ">>")
M.dedent_levels = indent_levels_work(-1, "<<")

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

-- ---------- sequence (renumber inside a selection) ----------

--- Renumber the ordinal tokens (`1.`, `a)`, `II.`) inside the current Visual
--- selection, in order of appearance — whatever precedes them, in any
--- filetype. Covers what `M.renumber` structurally cannot: numbered Markdown
--- headlines and inline numbers in prose.
---
--- Visual mode only, and deliberately not an Ex command for either charwise
--- case: `:'<,'>` ranges are always linewise, so the column bounds a
--- mid-line or multi-line charwise selection depends on would be thrown
--- away before the command ever ran.
---
--- A charwise (`v`) selection — same-line or spanning several lines — is
--- rewritten in place (`nvim_buf_set_text`/`nvim_buf_set_lines`, keeping
--- whatever precedes the selection's start and follows its end untouched)
--- and reselected on its new bounds (the text can get wider, `9.` -> `10.`).
--- Anything else — linewise (`V`), or a selection cascade can't read column
--- bounds for at all (blockwise) — is treated as a whole-line range and
--- reselected linewise.
---@return nil
function M.renumber_selection()
  local bufnr = vim.api.nvim_get_current_buf()
  local opts = config.get("sequence")
  if not (type(opts) == "table" and opts.enable and Context.writable(bufnr)) then
    feed("gv")
    return
  end

  local row, scol, ecol = lib.chars()
  if row then
    ---@cast scol integer
    ---@cast ecol integer
    local changed, new_ecol = sequence.span(bufnr, row, scol, ecol, opts)
    lib.reselect_chars(row, scol, changed and new_ecol or ecol)
    return
  end

  local srow, mscol, erow, mecol = lib.chars_multiline()
  if srow then
    ---@cast mscol integer
    ---@cast erow integer
    ---@cast mecol integer
    local changed, new_ecol = sequence.span_multi(bufnr, srow, mscol, erow, mecol, opts)
    lib.reselect_chars_multiline(srow, mscol, erow, changed and new_ecol or mecol)
    return
  end

  lib.keep_lines(function(s, e)
    sequence.range(bufnr, s, e, opts)
  end)
end

-- ---------- dot-repeatable actions ----------

---@internal
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

---@internal
--- Toggle a plain unordered bullet on the cursor line; works without an
--- existing marker (unlike `checkbox`/`cycle_type`, which only ever advance
--- one). Shared by the `-` and `*` variants.
--- Count for the bullet/star toggles, captured before the dot-repeat
--- trampoline like `pending_cycle_count`.
---
--- A count here widens the *scope* rather than repeating the action: `3<A-->`
--- toggles the next three lines, not the cursor line three times (which would
--- be a no-op for an even count). Same reinterpretation `<leader>et` uses in
--- emojis.nvim, and the only one a toggle can sensibly give a count.
---@type integer
local pending_toggle_count = 1

---@param single fun(ctx: CascadeContext, opts: CascadeListOpts): boolean
---@param range fun(bufnr: integer, srow: integer, erow: integer, dir: integer, opts: CascadeListOpts)
---@return fun()
local function bullet_toggle_work(single, range)
  return function()
    local ctx = Context.new()
    local opts = config.get("lists")
    if not (lists_active(ctx) and lf("bullet_toggle")) then
      return
    end

    if pending_toggle_count > 1 then
      local last = math.min(ctx.row0 + pending_toggle_count - 1, vim.api.nvim_buf_line_count(ctx.bufnr) - 1)
      range(ctx.bufnr, ctx.row0, last, 1, opts)
      return
    end

    dispatch.try({
      function(c)
        return single(c, opts)
      end,
    }, ctx)
  end
end

---@internal
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

---@internal
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

---@internal
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

---@internal
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
--- Count for the cycle keys, captured the same way and for the same reason as
--- `pending_swap_count` below: `cycle_word_next` and friends run through the
--- dot-repeat trampoline, so by the time the deferred work fires the count
--- typed on the triggering keypress is gone from `vim.v.count1`.
---@type integer
local pending_cycle_count = 1

--- Cycle the token under the cursor `pending_cycle_count` times.
---
--- Stepping N times rather than jumping N places keeps every group kind
--- correct with one loop: a 2-state toggle lands where its parity says, a
--- 3-state cycle wraps, and an ISO date rolls over months properly (`3<C-y>`
--- on `2026-08-30` is `2026-09-02`, not day 33).
---
--- The two fallbacks re-emit the count instead of swallowing it, since both
--- keys mean something counted natively: `3<C-a>` increments a number by 3,
--- and `3<C-y>` scrolls three lines. Dropping it there would have made the
--- count silently mean "1" exactly where the user could see it should not.
local function cycle_word_work(dir, number_key, own_key)
  return function()
    local count = pending_cycle_count
    local opts = config.get("cycle")
    if not opts.enable then
      feed(count > 1 and (count .. own_key) or own_key)
      return
    end
    local ctx = Context.new()
    if not Context.writable(ctx.bufnr) or not ft_in(opts.filetypes, ctx.ft) then
      feed(count > 1 and (count .. own_key) or own_key)
      return
    end

    if cf("date") then
      -- Re-read the line each step: `date.step` works off the text, and the
      -- replacement can change its length (`2026-08-09` -> `2026-08-10`).
      local stepped = false
      for _ = 1, count do
        local cur = Context.new(ctx.bufnr)
        local s0, e0, repl = date.step(cur.line, cur.col0, dir)
        if not s0 then
          break
        end
        vim.api.nvim_buf_set_text(cur.bufnr, cur.row0, s0, cur.row0, e0, { repl })
        stepped = true
      end
      if stepped then
        return
      end
    end

    if cf("word") then
      local cycled = false
      for _ = 1, count do
        if not word_cycle.cycle(Context.new(ctx.bufnr), opts, dir) then
          break
        end
        cycled = true
      end
      if cycled then
        return
      end
    end

    local _, _, text = token.span(ctx.line, ctx.col0)
    if opts.number_fallback and token.is_numeric(text) then
      feed(count > 1 and (count .. number_key) or number_key)
    else
      feed(count > 1 and (count .. own_key) or own_key)
    end
  end
end

--- Show an interactive picker over every entry in the cursor's cycle group
--- (word or operator), replacing it with whichever the user picks. Silent
--- no-op when the cursor isn't on a cyclable token -- there's no "own key"
--- Add a cycle group at runtime.
---
--- `cycle.groups` is otherwise config-only, so trying out a group meant
--- editing the config and reloading — enough friction that you simply
--- wouldn't, for a group you need for the next ten minutes. This appends to
--- the live table, which `word_cycle.groups_for` reads on every keypress.
---
--- Deliberately **not** persisted: it lasts for the session, and the config
--- file stays the single source of truth for groups you actually want to
--- keep. A group added here and then forgotten should not quietly outlive
--- the reason it was added.
---@param raw string  # comma-separated values, e.g. "on,off,maybe"
---@return boolean added
function M.cycle_group_add(raw)
  local opts = config.get("cycle")
  if type(opts) ~= "table" then
    return false
  end

  local values = {}
  local seen = {}
  for part in tostring(raw or ""):gmatch("[^,]+") do
    local v = vim.trim(part)
    -- Duplicates inside one group would make the cycle stall on the repeat.
    if v ~= "" and not seen[v] then
      seen[v] = true
      values[#values + 1] = v
    end
  end

  if #values < 2 then
    notify.warn("cycle add: need at least two distinct comma-separated values")
    return false
  end

  opts.groups = opts.groups or {}
  opts.groups[#opts.groups + 1] = values
  notify.info("cycle group added: " .. table.concat(values, " -> "))
  return true
end

--- Remove the first runtime cycle group containing `value`.
---@param value string
---@return boolean removed
function M.cycle_group_remove(value)
  local opts = config.get("cycle")
  value = vim.trim(tostring(value or ""))
  if type(opts) ~= "table" or type(opts.groups) ~= "table" or value == "" then
    return false
  end

  for i = #opts.groups, 1, -1 do
    if vim.tbl_contains(opts.groups[i], value) then
      local removed = table.remove(opts.groups, i)
      notify.info("cycle group removed: " .. table.concat(removed, " -> "))
      return true
    end
  end

  notify.warn("cycle remove: no group contains " .. vim.inspect(value))
  return false
end

--- Report the cycle groups in effect for the current buffer.
---
--- Global groups plus this filetype's, which is what actually applies — the
--- two are separate config keys, so reading either one alone answers the
--- wrong question.
---@return nil
function M.cycle_groups_list()
  local opts = config.get("cycle")
  if type(opts) ~= "table" then
    return
  end

  local ft = vim.bo[vim.api.nvim_get_current_buf()].filetype
  local per_ft = (type(opts.per_filetype) == "table" and opts.per_filetype[ft]) or {}

  local lines = { ("cycle groups in effect for %s:"):format(ft ~= "" and ft or "<no filetype>") }
  for _, grp in ipairs(opts.groups or {}) do
    lines[#lines + 1] = "  " .. table.concat(grp, " -> ")
  end
  for _, grp in ipairs(per_ft) do
    lines[#lines + 1] = ("  %s   (%s only)"):format(table.concat(grp, " -> "), ft)
  end

  if #lines == 1 then
    notify.info("no cycle groups configured")
    return
  end
  notify.info(table.concat(lines, "\n"))
end

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
local bullet_toggle_repeatable =
  dotrepeat.repeatable("bullet_toggle", bullet_toggle_work(quick_toggle.bullet, quick_toggle.bullet_range))
local star_toggle_repeatable = dotrepeat.repeatable("star_toggle", bullet_toggle_work(quick_toggle.star, quick_toggle.star_range))

--- Toggle a `-` bullet on the cursor line. `N` covers the next N lines.
---@return nil
function M.bullet_toggle()
  pending_toggle_count = vim.v.count1
  bullet_toggle_repeatable()
end

--- Toggle a `*` bullet on the cursor line. `N` covers the next N lines.
---@return nil
function M.star_toggle()
  pending_toggle_count = vim.v.count1
  star_toggle_repeatable()
end
M.number_toggle = dotrepeat.repeatable("number_toggle", number_toggle_work)
M.checkbox_toggle = dotrepeat.repeatable("checkbox_toggle", checkbox_toggle_work)
M.cycle_type_next = dotrepeat.repeatable("cycle_type_next", cycle_type_work(1))
M.cycle_type_prev = dotrepeat.repeatable("cycle_type_prev", cycle_type_work(-1))
local cycle_next_repeatable = dotrepeat.repeatable("cycle_word_next", cycle_word_work(1, "<C-a>", "<C-y>"))
local cycle_prev_repeatable = dotrepeat.repeatable("cycle_word_prev", cycle_word_work(-1, "<C-x>", "<C-x>"))
local increment_repeatable = dotrepeat.repeatable("increment", cycle_word_work(1, "<C-a>", "+"))
local decrement_repeatable = dotrepeat.repeatable("decrement", cycle_word_work(-1, "<C-x>", "-"))

--- Capture the count before the trampoline, then run. `.` afterwards replays
--- with this same stashed count, matching how `swap_right`/`swap_left` behave.
---@param fn fun()
---@return fun()
local function counted_cycle(fn)
  return function()
    pending_cycle_count = vim.v.count1
    fn()
  end
end

--- Cycle the token under the cursor forward. `N` cycles N steps.
---@return nil
M.cycle_word_next = counted_cycle(cycle_next_repeatable)

--- Cycle the token under the cursor backward. `N` cycles N steps.
---@return nil
M.cycle_word_prev = counted_cycle(cycle_prev_repeatable)

--- Increment the token under the cursor. `N` steps N times.
---@return nil
M.increment = counted_cycle(increment_repeatable)

--- Decrement the token under the cursor. `N` steps N times.
---@return nil
M.decrement = counted_cycle(decrement_repeatable)

-- ---------- block / visual transforms ----------

---@internal
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

---@internal
--- Resolve the block range at the cursor for a transform.
---@param ctx CascadeContext
---@return integer|nil srow, integer|nil erow
local function block_range(ctx)
  local opts = config.get("lists")
  return transform.block_range(ctx.bufnr, ctx.row0, opts)
end

---@internal
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

---@internal
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

---@internal
--- 0-based inclusive row range a `:command` addresses: its explicit range if
--- it has one, else the cursor line.
---@param cmd table # The nvim user-command argument table.
---@return integer srow, integer erow
local function command_rows(cmd)
  if cmd.range and cmd.range > 0 then
    return cmd.line1 - 1, cmd.line2 - 1
  end
  local r = vim.api.nvim_win_get_cursor(0)[1] - 1
  return r, r
end

--- Run `:Cascade renumber` from a `:command` (range-aware; `scope == "all"`
--- sweeps every list block in the buffer instead of just the current one,
--- `scope == "selection"` renumbers the ordinal tokens *inside* the lines
--- rather than the list markers — see `M.renumber_selection`).
---@param cmd table # The nvim user-command argument table.
---@param scope string|nil # "all", "selection", or nil/"block" for the range/cursor block.
---@return nil
function M.run_renumber_command(cmd, scope)
  local bufnr = vim.api.nvim_get_current_buf()
  if not Context.writable(bufnr) then
    return
  end

  -- The sequence domain has its own switch and is filetype-independent, so it
  -- is gated before (and separately from) the list domain's.
  if scope == "selection" then
    local seq = config.get("sequence")
    if type(seq) == "table" and seq.enable then
      local s, e = command_rows(cmd)
      sequence.range(bufnr, s, e, seq)
    end
    return
  end

  local opts = config.get("lists")
  if not opts.enable then
    return
  end
  if scope == "all" then
    pcall(renumber.all, bufnr, opts)
    return
  end
  local s, e
  if cmd.range and cmd.range > 0 then
    s, e = command_rows(cmd)
  else
    s, e = transform.block_range(bufnr, vim.api.nvim_win_get_cursor(0)[1] - 1, opts)
  end
  if s and e then
    pcall(renumber.tree, bufnr, s, e, opts, true)
  end
end

---@internal
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

---@internal
--- Internal: normal-mode move. `N` moves N lines.
--- Not dot-repeat wrapped, so `vim.v.count1` is still the keypress's own here
--- and needs no stashing. Moving one line at a time N times rather than
--- jumping N lines keeps `move_mod.line`'s reindent and list renumbering
--- correct at every step; it stops early at the buffer edge instead of
--- erroring.
---@param dir integer # -1 up, 1 down.
---@return nil
function M._move(dir)
  local bufnr = vim.api.nvim_get_current_buf()
  if not Context.writable(bufnr) or not lf("move") then
    return
  end
  local opts = config.get("lists")
  for _ = 1, vim.v.count1 do
    if move_mod.line(bufnr, dir, opts) == false then
      break
    end
  end
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

---@internal
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

---@internal
--- `swap_work`/`swap_word_work` run dot-repeated, deferred through
--- `dotrepeat_run`'s `operatorfunc`/`g@l` trampoline (native Vim, or
--- `lib.nvim.dotrepeat`'s `vim.cmd("normal! g@l")`) -- by the time that
--- fires, the count typed on the *triggering* keypress (e.g. `3` in
--- `3<leader><Right>`) is long gone from `vim.v.count1`, because neither
--- trampoline re-embeds it into the replayed `g@l`. So the count has to be
--- captured here, at the one point where `vim.v.count1` is still the
--- keypress's own -- immediately, before the trampoline -- and stashed for
--- the deferred swap loop to read instead of `vim.v.count1`. `.` afterwards
--- replays with this same stashed count (not a fresh one, since native
--- dot-repeat re-enters `operatorfunc` directly, bypassing this capture).
---@type integer
local pending_swap_count = 1

--- Swap the char under the cursor with its right (`dir = 1`) or left
--- (`dir = -1`) neighbor, `pending_swap_count` times (default 1) — a plain
--- call moves it one position, `3<leader><Right>` drags it three positions
--- right. Stops early (rather than erroring) if it hits the line boundary
--- before that many swaps are done. No-op when disabled.
---@param dir integer
---@return fun()
local function swap_work(dir)
  return function()
    local bufnr = vim.api.nvim_get_current_buf()
    local opts = config.get("transpose")
    if not (opts.enable and xf("char") and Context.writable(bufnr)) then
      return
    end
    for _ = 1, pending_swap_count do
      if not transpose_char.char(Context.new(bufnr), dir) then
        break
      end
    end
  end
end

local swap_right_repeatable = dotrepeat.repeatable("swap_right", swap_work(1))
local swap_left_repeatable = dotrepeat.repeatable("swap_left", swap_work(-1))

--- Swap the char under the cursor with its right neighbor. `N` count swaps N times.
---@return nil
function M.swap_right()
  pending_swap_count = vim.v.count1
  swap_right_repeatable()
end

--- Swap the char under the cursor with its left neighbor. `N` count swaps N times.
---@return nil
function M.swap_left()
  pending_swap_count = vim.v.count1
  swap_left_repeatable()
end

---@internal
--- Swap the word under the cursor with its right (`dir = 1`) or left
--- (`dir = -1`) neighbor word, `pending_swap_count` times (default 1) — same
--- count convention and capture-timing reasoning as `swap_work`. No-op when
--- disabled, the cursor isn't on a word, or there's no neighbor word left on
--- the line.
---@param dir integer
---@return fun()
local function swap_word_work(dir)
  return function()
    local bufnr = vim.api.nvim_get_current_buf()
    local opts = config.get("transpose")
    if not (opts.enable and xf("word") and Context.writable(bufnr)) then
      return
    end
    for _ = 1, pending_swap_count do
      if not transpose_word.word(Context.new(bufnr), dir) then
        break
      end
    end
  end
end

local swap_word_right_repeatable = dotrepeat.repeatable("swap_word_right", swap_word_work(1))
local swap_word_left_repeatable = dotrepeat.repeatable("swap_word_left", swap_word_work(-1))

--- Swap the word under the cursor with its right neighbor word. `N` count swaps N times.
---@return nil
function M.swap_word_right()
  pending_swap_count = vim.v.count1
  swap_word_right_repeatable()
end

--- Swap the word under the cursor with its left neighbor word. `N` count swaps N times.
---@return nil
function M.swap_word_left()
  pending_swap_count = vim.v.count1
  swap_word_left_repeatable()
end

---@internal
--- Swap the visual selection with its right (`dir = 1`) or left (`dir = -1`)
--- neighbor, `v:count1` times, keeping the swapped text itself selected
--- afterwards. `transpose` is `transpose_char.selection` or
--- `transpose_word.word_selection` — same signature, neighbor unit differs.
--- The neighbor moves into the selection's old slot, so the selected text
--- shifts by the neighbor's width each swap — each iteration reselects the
--- *new* bounds the transpose function returns, not the original ones
--- (unlike `keep_chars`, which assumes the selected span never moves). No-op
--- across multiple lines, at the line boundary, when there's no neighbor, or
--- when disabled — the selection is restored via `gv` (matching
--- `_move_visual`'s convention) in those cases.
---@param transpose fun(bufnr: integer, row0: integer, scol0: integer, ecol0: integer, dir: integer): boolean, integer?, integer?
---@param feature string # transpose feature key gating this swap ("char"/"word").
---@param dir integer
---@return nil
local function swap_visual(transpose, feature, dir)
  local bufnr = vim.api.nvim_get_current_buf()
  local opts = config.get("transpose")
  if not (opts.enable and xf(feature) and Context.writable(bufnr)) then
    feed("gv")
    return
  end
  local row, scol, ecol = lib.chars()
  if not row then
    feed("gv")
    return
  end
  ---@cast scol integer
  ---@cast ecol integer
  local changed_any = false
  for _ = 1, vim.v.count1 do
    local changed, new_scol, new_ecol = transpose(bufnr, row, scol, ecol, dir)
    if not changed then
      break
    end
    ---@cast new_scol integer
    ---@cast new_ecol integer
    scol, ecol, changed_any = new_scol, new_ecol, true
  end
  if changed_any then
    lib.reselect_chars(row, scol, ecol)
  else
    feed("gv")
  end
end

--- Swap the visual selection with its right neighbor char.
---@return nil
function M.swap_right_visual()
  swap_visual(transpose_char.selection, "char", 1)
end

--- Swap the visual selection with its left neighbor char.
---@return nil
function M.swap_left_visual()
  swap_visual(transpose_char.selection, "char", -1)
end

--- Swap the visual selection with its right neighbor word.
---@return nil
function M.swap_word_right_visual()
  swap_visual(transpose_word.word_selection, "word", 1)
end

--- Swap the visual selection with its left neighbor word.
---@return nil
function M.swap_word_left_visual()
  swap_visual(transpose_word.word_selection, "word", -1)
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

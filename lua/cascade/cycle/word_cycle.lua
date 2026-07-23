---@module 'cascade.cycle.word_cycle'
---@brief Cycle the word (or operator) under the cursor through configured groups.
---@description
--- Detects the keyword token under the cursor, finds the cycle group it belongs
--- to (case-insensitively), and replaces it with the next/previous entry while
--- preserving the original capitalization. Numeric tokens are left for the
--- native `<C-y>`/`<C-x>` fallback. Per-filetype groups extend the global ones.
--- Operator-style group entries (`"=="`, `"&&"`, `"<"`, ...) aren't
--- `'iskeyword'` characters, so they're matched separately via
--- `token.operator_span` (a literal-position scan) before falling through to
--- the keyword-based token match.

local token = require("cascade.cycle.token")

local M = {}

--- Wrap an index inside `[1, n]` by `dir` (+1 next, -1 prev).
---@param n integer
---@param idx integer
---@param dir integer
---@return integer
local function wrap(n, idx, dir)
  if n == 0 then
    return 1
  end
  return ((idx - 1 + dir) % n) + 1
end

--- Build the effective group list for a filetype (global + per-filetype).
---@param opts CascadeCycleOpts
---@param ft string
---@return string[][]
local function groups_for(opts, ft)
  local extra = opts.per_filetype and opts.per_filetype[ft]
  if not extra or #extra == 0 then
    return opts.groups
  end
  local out = {}
  local k = 0
  for i = 1, #opts.groups do
    k = k + 1
    out[k] = opts.groups[i]
  end
  for i = 1, #extra do
    k = k + 1
    out[k] = extra[i]
  end
  return out
end

--- Find `text` (case-insensitively) among `groups`.
---@param groups string[][]
---@param text string
---@return string[]|nil group, integer|nil index
local function find_group(groups, text)
  local lower = text:lower()
  for i = 1, #groups do
    local grp = groups[i]
    for j = 1, #grp do
      if lower == grp[j]:lower() then
        return grp, j
      end
    end
  end
  return nil, nil
end

--- Resolve the cursor's operator or word token to its span and cycle group,
--- shared by `cycle` and `pick`. Operator groups are tried first (they
--- aren't `'iskeyword'` characters, so there's no risk of shadowing a word
--- match); numeric word tokens are excluded (native increment/decrement
--- territory).
---@param ctx CascadeContext
---@param opts CascadeCycleOpts
---@return integer|nil s, integer|nil e, string[]|nil group, integer|nil index, CascadeCaseShape|nil shape
--- `shape` is nil for an operator match (replace verbatim).
local function resolve(ctx, opts)
  local groups = groups_for(opts, ctx.ft)

  local op_s, op_e, op_text = token.operator_span(ctx.line, ctx.col0, groups)
  if op_s then
    ---@cast op_e integer
    ---@cast op_text string
    local op_found, op_idx = find_group(groups, op_text)
    if op_found then
      return op_s, op_e, op_found, op_idx, nil
    end
  end

  local s, e, text = token.span(ctx.line, ctx.col0)
  if not s then
    return nil, nil, nil, nil, nil
  end
  ---@cast e integer
  ---@cast text string
  if token.is_numeric(text) then
    return nil, nil, nil, nil, nil
  end

  local found, idx = find_group(groups, text)
  if not found then
    return nil, nil, nil, nil, nil
  end
  return s, e, found, idx, token.case_shape(text)
end

--- Try to cycle the cursor token. Returns true on a successful replacement.
---@param ctx CascadeContext
---@param opts CascadeCycleOpts
---@param dir integer # 1 forward, -1 backward.
---@return boolean handled
function M.cycle(ctx, opts, dir)
  local s, e, found, idx, shape = resolve(ctx, opts)
  if not found then
    return false
  end
  ---@cast e integer
  ---@cast idx integer

  local nxt = wrap(#found, idx, dir)
  local repl = shape and token.apply_shape(found[nxt]:lower(), shape) or found[nxt]
  vim.api.nvim_buf_set_text(ctx.bufnr, ctx.row0, s, ctx.row0, e, { repl })
  return true
end

--- Show an interactive picker (`vim.ui.select` -- Telescope-backed if the
--- user has `telescope-ui-select.nvim` registered, else Neovim's builtin
--- list) over every entry in the cursor's cycle group, and replace the span
--- with whichever the user picks. Returns `true` once a group was found and
--- the picker was shown (the actual buffer edit happens in `vim.ui.select`'s
--- callback, which may be asynchronous depending on the UI backend).
---@param ctx CascadeContext
---@param opts CascadeCycleOpts
---@return boolean handled
function M.pick(ctx, opts)
  local s, e, found, _, shape = resolve(ctx, opts)
  if not found then
    return false
  end
  ---@cast e integer

  vim.ui.select(found, { prompt = "Cascade: pick a value" }, function(choice)
    if not choice then
      return
    end
    local repl = shape and token.apply_shape(choice:lower(), shape) or choice
    vim.api.nvim_buf_set_text(ctx.bufnr, ctx.row0, s, ctx.row0, e, { repl })
  end)
  return true
end

return M

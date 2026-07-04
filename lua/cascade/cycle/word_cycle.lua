---@module 'cascade.cycle.word_cycle'
---@brief Cycle the word under the cursor through configured groups.
---@description
--- Detects the keyword token under the cursor, finds the cycle group it belongs
--- to (case-insensitively), and replaces it with the next/previous entry while
--- preserving the original capitalization. Numeric tokens are left for the
--- native `<C-y>`/`<C-x>` fallback. Per-filetype groups extend the global ones.

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

--- Try to cycle the cursor token. Returns true on a successful replacement.
---@param ctx CascadeContext
---@param opts CascadeCycleOpts
---@param dir integer # 1 forward, -1 backward.
---@return boolean handled
function M.cycle(ctx, opts, dir)
  local s, e, text = token.span(ctx.line, ctx.col0)
  if not s then
    return false
  end
  ---@cast e integer
  ---@cast text string

  -- Numbers belong to the native increment/decrement fallback.
  if token.is_numeric(text) then
    return false
  end

  local lower = text:lower()
  local shape = token.case_shape(text)
  local groups = groups_for(opts, ctx.ft)

  local found, found_idx
  for i = 1, #groups do
    local grp = groups[i]
    for j = 1, #grp do
      if lower == grp[j]:lower() then
        found, found_idx = grp, j
        break
      end
    end
    if found then
      break
    end
  end
  if not found then
    return false
  end

  local nxt = wrap(#found, found_idx, dir)
  local repl = token.apply_shape(found[nxt]:lower(), shape)
  vim.api.nvim_buf_set_text(ctx.bufnr, ctx.row0, s, ctx.row0, e, { repl })
  return true
end

return M

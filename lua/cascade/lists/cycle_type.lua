---@module 'cascade.lists.cycle_type'
---@brief Cycle one item's marker shape through `lists.cycle`.
---@description
--- Rotates a single list item between configured marker templates, e.g.
--- `-` -> `*` -> `+` -> `1.` -> `a)` -> `I.`. Ordered targets carry the item's
--- current sequence value when possible (else start at 1); checkbox and text are
--- preserved. Shape decoding lives in `cascade.lists.shape`. Dot-repeatable via
--- the central operatorfunc helper.

local marker = require("cascade.lists.marker")
local renumber = require("cascade.lists.renumber")
local shape = require("cascade.lists.shape")

local M = {}

--- Cycle the marker type on the cursor line forward (dir 1) or backward (-1).
---@param ctx CascadeContext
---@param opts CascadeListOpts
---@param dir integer
---@return boolean handled
function M.cycle(ctx, opts, dir)
  local cycle = opts.cycle
  if type(cycle) ~= "table" or #cycle == 0 then
    return false
  end
  local m = marker.parse(ctx.line, opts)
  if not m then
    return false
  end

  local idx
  for i = 1, #cycle do
    if shape.matches(m, shape.spec_of(cycle[i])) then
      idx = i
      break
    end
  end
  if not idx then
    idx = 1 -- current shape not in cycle; jump to the first entry
  end

  local nxt = ((idx - 1 + dir) % #cycle) + 1
  local spec = shape.spec_of(cycle[nxt])
  local value = shape.value_of(m)

  local new_m = {
    indent = m.indent,
    kind = spec.kind,
    marker = shape.token_for(spec, value),
    delim = spec.delim,
    checkbox = m.checkbox,
    text = m.text,
  }
  local new = marker.render(new_m) .. (m.text or "")
  if new == ctx.line then
    return false
  end
  vim.api.nvim_buf_set_lines(ctx.bufnr, ctx.row0, ctx.row0 + 1, false, { new })
  if opts.renumber and spec.kind ~= "unordered" then
    pcall(renumber.run, ctx.bufnr, ctx.row0, opts)
  end
  return true
end

return M

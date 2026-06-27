---@module 'cascade.lists.checkbox'
---@brief Toggle / cycle a checkbox through configurable states.
---@description
--- Generalizes the usual binary `[ ]` <-> `[x]` toggle into an N-state cycle
--- (e.g. `[ ]` -> `[x]` -> `[-]`). On a plain list item without a checkbox, the
--- first state is added, turning it into a checkbox item.

local marker = require("cascade.lists.marker")

local M = {}

--- Index of `state` in `states`, or nil.
---@param states string[]
---@param state string
---@return integer|nil
local function index_of(states, state)
  for i = 1, #states do
    if states[i] == state then
      return i
    end
  end
  return nil
end

--- Toggle/cycle the checkbox on the cursor line.
---@param ctx CascadeContext
---@param opts CascadeListOpts
---@return boolean handled
function M.toggle(ctx, opts)
  local m = marker.parse(ctx.line, opts)
  if not m then
    return false
  end
  local states = opts.checkbox.states
  if #states == 0 then
    return false
  end

  if m.checkbox == nil then
    -- Promote a plain bullet into a checkbox item.
    m.checkbox = states[1]
  else
    local idx = index_of(states, m.checkbox) or 0
    m.checkbox = states[(idx % #states) + 1]
  end

  local new = marker.render(m) .. (m.text or "")
  vim.api.nvim_buf_set_lines(ctx.bufnr, ctx.row0, ctx.row0 + 1, false, { new })
  return true
end

return M

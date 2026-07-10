---@module 'cascade.lists.quick_toggle'
---@brief Toggle a marker onto/off an arbitrary line, no existing marker required.
---@description
--- Complements `checkbox`/`cycle_type` (which only ever *advance* an existing
--- marker and no-op without one) with the opposite primitive: turn any line —
--- marked or not — into a specific marker shape, or strip it back to plain
--- text. `bullet`/`number` are a blunt on/off switch per shape (any existing
--- marker of a *different* kind is converted, not stacked); `checkbox` is a
--- full cycle that also creates the item from scratch and removes it again
--- after the last configured state, rather than cycling forever like
--- `cascade.lists.checkbox`.

local marker = require("cascade.lists.marker")
local renumber = require("cascade.lists.renumber")

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

--- Resolve indent + text for the cursor line: from a parsed marker if one
--- exists, else by splitting the raw line's leading whitespace off.
---@param m CascadeMarker|nil
---@param line string
---@return string indent, string text
local function indent_text(m, line)
  if m then
    return m.indent, m.text or ""
  end
  local indent = line:match("^(%s*)") or ""
  return indent, line:sub(#indent + 1)
end

--- Replace the cursor line, or no-op (return false) if unchanged.
---@param ctx CascadeContext
---@param new_line string
---@return boolean handled
local function apply(ctx, new_line)
  if new_line == ctx.line then
    return false
  end
  vim.api.nvim_buf_set_lines(ctx.bufnr, ctx.row0, ctx.row0 + 1, false, { new_line })
  return true
end

--- Toggle a plain `-` bullet on the cursor line: strip it if already an
--- unordered `-` item (checkbox included), otherwise set/convert the line to
--- one, preserving text and any existing checkbox.
---@param ctx CascadeContext
---@param opts CascadeListOpts
---@return boolean handled
function M.bullet(ctx, opts)
  local m = marker.parse(ctx.line, opts)
  if m and m.kind == "unordered" and m.marker == "-" then
    return apply(ctx, m.indent .. (m.text or ""))
  end
  local indent, text = indent_text(m, ctx.line)
  local new_m = { indent = indent, kind = "unordered", marker = "-", delim = "", checkbox = m and m.checkbox or nil, text = text }
  return apply(ctx, marker.render(new_m) .. text)
end

--- Toggle a `1.` numbered marker on the cursor line: strip it if already a
--- digit item, otherwise set/convert the line to one and let `renumber` (if
--- its "edit" trigger is on) resolve the actual sequence number from the
--- surrounding siblings.
---@param ctx CascadeContext
---@param opts CascadeListOpts
---@return boolean handled
function M.number(ctx, opts)
  local m = marker.parse(ctx.line, opts)
  if m and m.kind == "digit" then
    return apply(ctx, m.indent .. (m.text or ""))
  end

  local indent, text = indent_text(m, ctx.line)
  local new_m = { indent = indent, kind = "digit", marker = "1", delim = ".", checkbox = m and m.checkbox or nil, text = text }
  local handled = apply(ctx, marker.render(new_m) .. text)
  if handled and renumber.at(opts, "edit") then
    pcall(renumber.run, ctx.bufnr, ctx.row0, opts)
  end
  return handled
end

--- Cycle a `- [ ]` checkbox on the cursor line, creating it from a plain line
--- or an existing marker if needed. Unlike `cascade.lists.checkbox` (which
--- cycles forever once an item has a checkbox), the last configured state
--- rolls back to plain text — a full "insert -> cycle -> remove" toggle.
---@param ctx CascadeContext
---@param opts CascadeListOpts
---@return boolean handled
function M.checkbox(ctx, opts)
  local states = opts.checkbox.states
  if type(states) ~= "table" or #states == 0 then
    return false
  end

  local m = marker.parse(ctx.line, opts)

  if m and m.checkbox ~= nil then
    local idx = index_of(states, m.checkbox)
    if idx == #states then
      -- Last configured state: strip the whole item back to plain text.
      return apply(ctx, m.indent .. (m.text or ""))
    end
    local new_m = {
      indent = m.indent,
      kind = m.kind,
      marker = m.marker,
      delim = m.delim,
      checkbox = states[(idx or 0) % #states + 1],
      text = m.text,
    }
    return apply(ctx, marker.render(new_m) .. (m.text or ""))
  end

  -- No checkbox yet: promote the existing marker, or create a fresh "-" bullet.
  local indent, text = indent_text(m, ctx.line)
  local new_m = {
    indent = indent,
    kind = m and m.kind or "unordered",
    marker = m and m.marker or "-",
    delim = m and m.delim or "",
    checkbox = states[1],
    text = text,
  }
  return apply(ctx, marker.render(new_m) .. text)
end

return M

---@module 'cascade.lists.renumber'
---@brief Renumber a contiguous ordered list block at the cursor's indent level.
---@description
--- Operates only on ordered markers (digit/ascii/roman). Finds the run of lines
--- sharing the cursor item's indent and kind, then rewrites their markers as a
--- sequence starting from the first marker's value (so non-1 start offsets and
--- alphabetic/Roman lists are preserved). Lines that are more deeply indented
--- (children) are skipped over but left untouched.

local marker = require("cascade.lists.marker")
local roman = require("cascade.lists.roman")
local alpha = require("cascade.lists.alpha")

local M = {}

--- Format the n-th ordinal for an ordered kind, preserving case of `ref`.
---@param kind CascadeMarkerKind
---@param value integer
---@param ref string # The first marker, used for case.
---@return string
local function ordinal(kind, value, ref)
  if kind == "digit" then
    return tostring(value)
  end
  local s
  if kind == "ascii" then
    s = alpha.to_alpha(value)
  else
    s = roman.to_roman(value)
  end
  s = s or ref
  if ref == ref:upper() and ref ~= ref:lower() then
    return s:upper()
  end
  return s:lower()
end

--- Convert an ordered marker token to its integer value.
---@param kind CascadeMarkerKind
---@param token string
---@return integer|nil
local function value_of(kind, token)
  if kind == "digit" then
    return tonumber(token)
  elseif kind == "ascii" then
    return alpha.to_int(token)
  else
    return roman.to_int(token)
  end
end

--- Renumber the ordered block containing line `row0` (0-based).
---@param bufnr integer
---@param row0 integer
---@param opts CascadeListOpts
---@return boolean changed
function M.run(bufnr, row0, opts)
  local line = vim.api.nvim_buf_get_lines(bufnr, row0, row0 + 1, false)[1]
  if not line then
    return false
  end
  local cur = marker.parse(line, opts)
  if not cur or cur.kind == "unordered" then
    return false
  end

  local indent_w = #cur.indent
  -- Find the first line of the block (scan upward over same-indent same-kind).
  local total = vim.api.nvim_buf_line_count(bufnr)
  local function item_at(r)
    local l = vim.api.nvim_buf_get_lines(bufnr, r, r + 1, false)[1]
    if not l then
      return nil
    end
    return marker.parse(l, opts)
  end

  local first = row0
  while first - 1 >= 0 do
    local m = item_at(first - 1)
    if m and m.kind == cur.kind and #m.indent == indent_w then
      first = first - 1
    elseif m and #m.indent > indent_w then
      first = first - 1 -- child line, keep scanning past it
    else
      break
    end
  end

  local start_m = item_at(first)
  if not start_m then
    return false
  end
  local start_val = value_of(cur.kind, start_m.marker) or 1
  local ref = start_m.marker

  -- Walk down, rewriting same-indent same-kind siblings.
  local changed = false
  local seq = start_val
  local r = first
  while r < total do
    local m = item_at(r)
    if not m then
      break
    end
    if #m.indent < indent_w then
      break
    end
    if #m.indent == indent_w then
      if m.kind ~= cur.kind then
        break
      end
      local want = ordinal(cur.kind, seq, ref)
      if want ~= m.marker then
        m.marker = want
        local l = vim.api.nvim_buf_get_lines(bufnr, r, r + 1, false)[1]
        local new = marker.render(m) .. (m.text or "")
        if new ~= l then
          vim.api.nvim_buf_set_lines(bufnr, r, r + 1, false, { new })
          changed = true
        end
      end
      seq = seq + 1
    end
    r = r + 1
  end
  return changed
end

return M

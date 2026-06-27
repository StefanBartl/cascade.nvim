---@module 'cascade.lists.transform'
---@brief Block / range list transforms: form rotation and A-Z sort.
---@description
--- Operates on a line range — either the contiguous list block at the cursor
--- (`block_range`) or an explicit visual selection. `rotate` advances every item
--- at the block's base indent through `lists.forms` (a form combines a marker
--- shape with optional checkbox presence), so e.g. `1.` -> `1. [ ]` -> `- [ ]`.
--- `sort` reorders item text (with its checkbox) alphabetically and renumbers.
--- Items at a deeper indent are skipped so nested lists stay intact.

local marker = require("cascade.lists.marker")
local shape = require("cascade.lists.shape")

local M = {}

---@class CascadeForm
---@field spec CascadeTypeSpec
---@field checkbox boolean # whether this form carries a `[ ]` checkbox

--- Decode a form template, e.g. "1.", "1. [ ]", "- [ ]", "-".
---@param s string
---@return CascadeForm
local function parse_form(s)
  local checkbox = false
  local body = s:gsub("%s*%[%s?%]%s*$", "")
  if body ~= s then
    checkbox = true
  end
  body = vim.trim(body)
  return { spec = shape.spec_of(body), checkbox = checkbox }
end

--- Decode every configured form once.
---@param forms string[]
---@return CascadeForm[]
local function parse_forms(forms)
  local out = {}
  for i = 1, #forms do
    out[i] = parse_form(forms[i])
  end
  return out
end

--- Find the form index a marker currently has (shape + checkbox presence).
---@param m CascadeMarker
---@param parsed CascadeForm[]
---@return integer|nil
local function form_index(m, parsed)
  for i = 1, #parsed do
    local f = parsed[i]
    if shape.matches(m, f.spec) and ((m.checkbox ~= nil) == f.checkbox) then
      return i
    end
  end
  return nil
end

--- Read a buffer line (0-based), or nil.
---@param bufnr integer
---@param r integer
---@return string|nil
local function line_at(bufnr, r)
  return vim.api.nvim_buf_get_lines(bufnr, r, r + 1, false)[1]
end

--- The contiguous run of list-item lines containing `row0` (0-based, inclusive).
---@param bufnr integer
---@param row0 integer
---@param opts CascadeListOpts
---@return integer|nil srow, integer|nil erow
function M.block_range(bufnr, row0, opts)
  local function is_item(r)
    local l = line_at(bufnr, r)
    return l ~= nil and marker.parse(l, opts) ~= nil
  end
  if not is_item(row0) then
    return nil, nil
  end
  local s = row0
  while s - 1 >= 0 and is_item(s - 1) do
    s = s - 1
  end
  local total = vim.api.nvim_buf_line_count(bufnr)
  local e = row0
  while e + 1 < total and is_item(e + 1) do
    e = e + 1
  end
  return s, e
end

--- The first parsed item (and its row) within `[srow, erow]`.
---@param bufnr integer
---@param srow integer
---@param erow integer
---@param opts CascadeListOpts
---@return CascadeMarker|nil base, integer|nil row
local function first_item(bufnr, srow, erow, opts)
  for r = srow, erow do
    local l = line_at(bufnr, r)
    local m = l and marker.parse(l, opts)
    if m then
      return m, r
    end
  end
  return nil, nil
end

--- Rotate every base-indent item in `[srow, erow]` to the next/prev form.
---@param bufnr integer
---@param srow integer
---@param erow integer
---@param dir integer # 1 forward, -1 backward.
---@param opts CascadeListOpts
---@return boolean changed
function M.rotate(bufnr, srow, erow, dir, opts)
  local forms = opts.forms
  if type(forms) ~= "table" or #forms == 0 then
    return false
  end
  local parsed = parse_forms(forms)

  local base = first_item(bufnr, srow, erow, opts)
  if not base then
    return false
  end
  local base_indent = #base.indent

  local cur = form_index(base, parsed)
  local target_idx
  if cur then
    target_idx = ((cur - 1 + dir) % #parsed) + 1
  else
    target_idx = dir >= 0 and 1 or #parsed
  end
  local target = parsed[target_idx]
  local states = opts.checkbox.states

  local changed = false
  local counter = 1
  for r = srow, erow do
    local l = line_at(bufnr, r)
    local m = l and marker.parse(l, opts)
    if m and #m.indent == base_indent then
      local new_m = {
        indent = m.indent,
        kind = target.spec.kind,
        marker = shape.token_for(target.spec, counter),
        delim = target.spec.delim,
        text = m.text,
      }
      if target.checkbox then
        new_m.checkbox = m.checkbox or states[1]
      end
      local new = marker.render(new_m) .. (m.text or "")
      if new ~= l then
        vim.api.nvim_buf_set_lines(bufnr, r, r + 1, false, { new })
        changed = true
      end
      counter = counter + 1
    end
  end
  return changed
end

--- Sort base-indent items in `[srow, erow]` by text; renumber ordered markers.
---@param bufnr integer
---@param srow integer
---@param erow integer
---@param dir integer # 1 ascending (A-Z), -1 descending.
---@param opts CascadeListOpts
---@return boolean changed
function M.sort(bufnr, srow, erow, dir, opts)
  local base, _ = first_item(bufnr, srow, erow, opts)
  if not base then
    return false
  end
  local base_indent = #base.indent

  -- Collect rows + items at the base indent.
  local rows, items = {}, {}
  local k = 0
  for r = srow, erow do
    local l = line_at(bufnr, r)
    local m = l and marker.parse(l, opts)
    if m and #m.indent == base_indent then
      k = k + 1
      rows[k] = r
      items[k] = m
    end
  end
  if k < 2 then
    return false
  end

  -- Stable order of indices by text.
  local order = {}
  for i = 1, k do
    order[i] = i
  end
  table.sort(order, function(a, b)
    local ta, tb = (items[a].text or ""):lower(), (items[b].text or ""):lower()
    if ta == tb then
      return a < b -- stable
    end
    if dir < 0 then
      return ta > tb
    end
    return ta < tb
  end)

  local spec = {
    kind = base.kind,
    delim = base.delim,
    upper = base.marker == base.marker:upper() and base.marker ~= base.marker:lower(),
    bullet = base.marker,
  }

  local changed = false
  for pos = 1, k do
    local src = items[order[pos]]
    local new_m = {
      indent = base.indent,
      kind = base.kind,
      marker = shape.token_for(spec, pos),
      delim = base.delim,
      checkbox = src.checkbox,
      text = src.text,
    }
    local new = marker.render(new_m) .. (src.text or "")
    local cur = line_at(bufnr, rows[pos])
    if new ~= cur then
      vim.api.nvim_buf_set_lines(bufnr, rows[pos], rows[pos] + 1, false, { new })
      changed = true
    end
  end
  return changed
end

return M

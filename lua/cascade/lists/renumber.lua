---@module 'cascade.lists.renumber'
---@brief Renumber a contiguous ordered list block at the cursor's indent level.
---@description
--- Operates only on ordered markers (digit/ascii/roman). Finds the run of lines
--- sharing the cursor item's indent and kind, then rewrites their markers as a
--- sequence starting from the first marker's value (so non-1 start offsets and
--- alphabetic/Roman lists are preserved). Lines that are more deeply indented
--- (children, or a non-marker continuation paragraph wrapped under an item)
--- are skipped over but left untouched, so they don't break the sequence; a
--- blank line or a non-marker line at/above the item's own indent still does.

local marker = require("cascade.lists.marker")
local roman = require("cascade.lists.roman")
local alpha = require("cascade.lists.alpha")

local M = {}
local is_continuation = marker.is_continuation

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

--- Whether automatic renumbering should run for a given trigger.
---@param opts CascadeListOpts
---@param trigger CascadeRenumberTrigger
---@return boolean
function M.at(opts, trigger)
  local r = opts.renumber
  if type(r) ~= "table" or not r.enable or type(r.on) ~= "table" then
    return false
  end
  for i = 1, #r.on do
    if r.on[i] == trigger then
      return true
    end
  end
  return false
end

--- Tree-renumber every contiguous list block in the buffer (used on save).
---@param bufnr integer
---@param opts CascadeListOpts
---@return boolean changed
function M.all(bufnr, opts)
  local total = vim.api.nvim_buf_line_count(bufnr)
  local changed = false
  local r = 0
  while r < total do
    local l = vim.api.nvim_buf_get_lines(bufnr, r, r + 1, false)[1]
    local m0 = l and marker.parse(l, opts)
    if m0 then
      local base_w = #m0.indent
      local e = r
      while e + 1 < total do
        local nl = vim.api.nvim_buf_get_lines(bufnr, e + 1, e + 2, false)[1]
        if nl and (marker.parse(nl, opts) or is_continuation(nl, base_w)) then
          e = e + 1
        else
          break
        end
      end
      if M.tree(bufnr, r, e, opts) then
        changed = true
      end
      r = e + 1
    else
      r = r + 1
    end
  end
  return changed
end

--- Indent-aware renumber of the whole block `[srow, erow]` (0-based, inclusive).
---
--- Walks the block once with a counter per indent width: a deeper level resets
--- to 1, returning to a shallower level continues it, and the block's base level
--- keeps its first item's start offset. This is the behavior wanted after an
--- indent/outdent — each nesting level forms its own clean sequence.
---@param bufnr integer
---@param srow integer
---@param erow integer
---@param opts CascadeListOpts
---@return boolean changed
function M.tree(bufnr, srow, erow, opts)
  local lines = vim.api.nvim_buf_get_lines(bufnr, srow, erow + 1, false)
  if #lines == 0 then
    return false
  end

  -- Base = smallest indent width among list items; its first ordered item sets
  -- the start offset so a list that begins at e.g. "3." stays anchored there.
  local base_w, base_start = nil, 1
  for i = 1, #lines do
    local m = marker.parse(lines[i], opts)
    if m then
      local w = #m.indent
      if base_w == nil or w < base_w then
        base_w = w
      end
    end
  end
  if base_w == nil then
    return false
  end
  for i = 1, #lines do
    local m = marker.parse(lines[i], opts)
    if m and #m.indent == base_w and m.kind ~= "unordered" then
      base_start = value_of(m.kind, m.marker) or 1
      break
    end
  end

  local counters = {} ---@type table<integer, integer>
  counters[base_w] = base_start - 1

  -- Build the whole block in memory and commit it with a single set_lines. One
  -- contiguous edit gives the markdown treesitter highlighter a clean range to
  -- re-parse; rewriting line-by-line instead scatters many small structural
  -- edits at the parser, which can leave a nested marker stale (un-highlighted).
  local out = {} ---@type string[]
  local changed = false
  for i = 1, #lines do
    local line = lines[i]
    out[i] = line
    local m = marker.parse(line, opts)
    if not m then
      if not is_continuation(line, base_w) then
        -- A real break (blank, or text at/above the list's own indent) ends
        -- every running sequence. Deeper continuation content (e.g. a
        -- wrapped paragraph under an item) is left untouched instead.
        counters = {}
        counters[base_w] = base_start - 1
      end
    else
      local w = #m.indent
      -- Returning to a shallower level invalidates all deeper counters.
      for cw in pairs(counters) do
        if cw > w then
          counters[cw] = nil
        end
      end
      if m.kind ~= "unordered" then
        local seed = (w == base_w) and (base_start - 1) or 0
        local cur = (counters[w] or seed) + 1
        counters[w] = cur
        local want = ordinal(m.kind, cur, m.marker)
        if want ~= m.marker then
          m.marker = want
          local new = marker.render(m) .. (m.text or "")
          if new ~= line then
            out[i] = new
            changed = true
          end
        end
      end
    end
  end
  if changed then
    vim.api.nvim_buf_set_lines(bufnr, srow, srow + #lines, false, out)
  end
  return changed
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
  -- Find the first line of the block (scan upward over same-indent same-kind,
  -- child lines, and deeper-indented continuation content).
  local total = vim.api.nvim_buf_line_count(bufnr)
  local function line_at(r)
    return vim.api.nvim_buf_get_lines(bufnr, r, r + 1, false)[1]
  end
  local function item_at(r)
    local l = line_at(r)
    if not l then
      return nil
    end
    return marker.parse(l, opts)
  end

  local first = row0
  while first - 1 >= 0 do
    local l = line_at(first - 1)
    local m = l and marker.parse(l, opts) or nil
    if m and m.kind == cur.kind and #m.indent == indent_w then
      first = first - 1
    elseif m and #m.indent > indent_w then
      first = first - 1 -- child line, keep scanning past it
    elseif not m and l and is_continuation(l, indent_w) then
      first = first - 1 -- continuation content, keep scanning past it
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

  -- Walk down, rewriting same-indent same-kind siblings. Collect the run into
  -- `out` and commit once (see M.tree) so the highlighter sees a single edit.
  local out = {} ---@type string[]
  local changed = false
  local seq = start_val
  local r = first
  while r < total do
    local l = vim.api.nvim_buf_get_lines(bufnr, r, r + 1, false)[1]
    local m = l and marker.parse(l, opts) or nil
    -- Deeper continuation content (e.g. a wrapped paragraph under an item)
    -- passes through unchanged without ending the run; anything else
    -- (blank, or text at/above the item's own indent) ends it.
    if not m and l and is_continuation(l, indent_w) then
      out[#out + 1] = l
      r = r + 1
    elseif not m or #m.indent < indent_w then
      break
    else
      local newl = l
      if #m.indent == indent_w then
        if m.kind ~= cur.kind then
          break
        end
        local want = ordinal(cur.kind, seq, ref)
        if want ~= m.marker then
          m.marker = want
          local new = marker.render(m) .. (m.text or "")
          if new ~= l then
            newl = new
            changed = true
          end
        end
        seq = seq + 1
      end
      out[#out + 1] = newl
      r = r + 1
    end
  end
  if changed then
    vim.api.nvim_buf_set_lines(bufnr, first, first + #out, false, out)
  end
  return changed
end

return M

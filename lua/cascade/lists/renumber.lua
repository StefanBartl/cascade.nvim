---@module 'cascade.lists.renumber'
--- Renumber a contiguous ordered list block at the cursor's indent level.
---
--- Operates only on ordered markers (digit/ascii/roman). Finds the run of lines
--- sharing the cursor item's indent and kind, then rewrites their markers as a
--- sequence starting from the first marker's value (so non-1 start offsets and
--- alphabetic/Roman lists are preserved). A non-marker, non-blank line (e.g. a
--- wrapped continuation paragraph or note under an item) never breaks the
--- sequence, regardless of its own indent — only a run of more than
--- `lists.renumber.blank_break` consecutive blank lines does (default `0`, i.e.
--- any blank line breaks the block; see `cascade.lists.marker`).

local marker = require("cascade.lists.marker")
local roman = require("cascade.lists.roman")
local alpha = require("cascade.lists.alpha")

local M = {}

---@internal
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

---@internal
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
--- Renumbers existing, already-typed text rather than reacting to a live
--- indent/outdent, so nested levels preserve their own start offset
--- (`preserve_start = true`; see `M.tree`).
---@param bufnr integer
---@param opts CascadeListOpts
---@return boolean changed
function M.all(bufnr, opts)
  local total = vim.api.nvim_buf_line_count(bufnr)
  local max_blank = marker.blank_run(opts)
  local changed = false
  local r = 0
  while r < total do
    local l = vim.api.nvim_buf_get_lines(bufnr, r, r + 1, false)[1]
    if l and marker.parse(l, opts) then
      local e = r
      local blanks = 0
      while e + 1 < total do
        local nl = vim.api.nvim_buf_get_lines(bufnr, e + 1, e + 2, false)[1]
        if nl == nil then
          break
        end
        local continues
        continues, blanks = marker.is_continuation(nl, blanks, max_blank)
        if not continues then
          break
        end
        e = e + 1
      end
      if M.tree(bufnr, r, e, opts, true) then
        changed = true
      end
      r = e + 1
    else
      r = r + 1
    end
  end
  return changed
end

--- Read the block's current base-level start value without rewriting
--- anything, i.e. the same value `M.tree` would derive from `lines` on its
--- own. For a caller that is about to reorder the block (`cascade.lists.move`)
--- and only then call `M.tree`: by the time `M.tree` runs, whichever line
--- ended up physically first is not necessarily the line that was first
--- before the reorder, so scanning post-move picks up that line's own
--- (possibly stale, not-yet-renumbered) value as the new anchor -- one off
--- with every move in the same direction, cumulatively. Call this before the
--- reorder and pass its result as `M.tree`'s `forced_base_start`.
---@param bufnr integer
---@param srow integer
---@param erow integer
---@param opts CascadeListOpts
---@return integer|nil # nil if the block has no base-level ordered item.
function M.peek_base_start(bufnr, srow, erow, opts)
  local lines = vim.api.nvim_buf_get_lines(bufnr, srow, erow + 1, false)
  local base_w = nil
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
    return nil
  end
  for i = 1, #lines do
    local m = marker.parse(lines[i], opts)
    if m and #m.indent == base_w and m.kind ~= "unordered" then
      return value_of(m.kind, m.marker) or 1
    end
  end
  return nil
end

--- Indent-aware renumber of the whole block `[srow, erow]` (0-based, inclusive).
---
--- Walks the block once with a counter per indent width: the block's base
--- level always keeps its first item's start offset. A nested level's
--- behavior depends on `preserve_start`: by default it resets to `1` on its
--- first occurrence — the right call right after an indent/outdent, where a
--- freshly demoted single item should start a clean new run rather than keep
--- a stale number from its old level. With `preserve_start = true` (used for
--- renumbering already-existing text, e.g. `M.all` on save), a nested level
--- instead seeds from its own first marker's value, so a deliberately
--- authored non-1 start survives. Either way, returning to a shallower level
--- invalidates deeper counters, so the next time a level is reached it
--- reseeds from scratch.
---@param bufnr integer
---@param srow integer
---@param erow integer
---@param opts CascadeListOpts
---@param preserve_start boolean|nil # Seed nested levels from their own first marker instead of resetting to 1. Default false.
---@param forced_base_start integer|nil # Use this instead of scanning `lines` -- see `M.peek_base_start`.
---@return boolean changed
function M.tree(bufnr, srow, erow, opts, preserve_start, forced_base_start)
  local lines = vim.api.nvim_buf_get_lines(bufnr, srow, erow + 1, false)
  if #lines == 0 then
    return false
  end

  -- Base = smallest indent width among list items; its first ordered item sets
  -- the start offset so a list that begins at e.g. "3." stays anchored there
  -- -- unless `forced_base_start` overrides it (see that parameter's doc).
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
  if forced_base_start then
    base_start = forced_base_start
  else
    for i = 1, #lines do
      local m = marker.parse(lines[i], opts)
      if m and #m.indent == base_w and m.kind ~= "unordered" then
        base_start = value_of(m.kind, m.marker) or 1
        break
      end
    end
  end

  local counters = {} ---@type table<integer, integer>
  counters[base_w] = base_start - 1

  -- Which kind each indent width's running list has actually been using so
  -- far, THIS pass. `ascii`/`roman` overlap on seven letters (see
  -- `marker.parse`'s own doc), so without this a perfectly ordinary
  -- "a) b) c) d)" list would have "c)" silently reinterpreted as roman and
  -- renumbered "iii)" the moment it's reached, purely because `types` tries
  -- roman first (needed elsewhere so a cycled "I." reads back as roman, not
  -- the 9th letter). Once a width's first item resolves a kind, every later
  -- item at that same width is parsed with that kind preferred, so an
  -- ambiguous letter keeps reading the way the rest of ITS OWN list already
  -- does instead of whatever `types`' fixed order would pick in isolation.
  local kind_by_width = {} ---@type table<integer, CascadeMarkerKind>

  -- Build the whole block in memory and commit it with a single set_lines. One
  -- contiguous edit gives the markdown treesitter highlighter a clean range to
  -- re-parse; rewriting line-by-line instead scatters many small structural
  -- edits at the parser, which can leave a nested marker stale (un-highlighted).
  local out = {} ---@type string[]
  local changed = false
  local blanks = 0
  local max_blank = marker.blank_run(opts)
  for i = 1, #lines do
    local line = lines[i]
    out[i] = line
    local peek_indent = line:match("^(%s*)") or ""
    local m = marker.parse(line, opts, kind_by_width[#peek_indent])
    if not m then
      local continues
      continues, blanks = marker.is_continuation(line, blanks, max_blank)
      if not continues then
        -- A real break (too many consecutive blank lines) ends every running
        -- sequence, kind memory included. Non-blank continuation content is
        -- left untouched instead.
        counters = {}
        counters[base_w] = base_start - 1
        kind_by_width = {}
      end
    else
      blanks = 0
      local w = #m.indent
      -- Returning to a shallower level invalidates all deeper counters --
      -- and the kind memory that went with them, so a deeper run started
      -- fresh later at the same width gets to re-resolve its own kind rather
      -- than inheriting a now-unrelated list's.
      for cw in pairs(counters) do
        if cw > w then
          counters[cw] = nil
          kind_by_width[cw] = nil
        end
      end
      if m.kind ~= "unordered" then
        kind_by_width[w] = m.kind
        -- First time this width is seen (or seen again after a shallower
        -- return invalidated it): reset to 1, unless preserve_start asks to
        -- seed from this item's own marker value instead.
        local seed = (w == base_w) and (base_start - 1) or (preserve_start and ((value_of(m.kind, m.marker) or 1) - 1)) or 0
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
  local max_blank = marker.blank_run(opts)
  -- Find the first line of the block (scan upward over same-indent same-kind
  -- siblings, deeper child lines, and non-marker continuation content).
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
  local blanks = 0
  while first - 1 >= 0 do
    local l = line_at(first - 1)
    local m = l and marker.parse(l, opts) or nil
    if m and m.kind == cur.kind and #m.indent == indent_w then
      first = first - 1
      blanks = 0
    elseif m and #m.indent > indent_w then
      first = first - 1 -- child line, keep scanning past it
      blanks = 0
    elseif not m and l then
      local continues
      continues, blanks = marker.is_continuation(l, blanks, max_blank)
      if not continues then
        break
      end
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
  blanks = 0
  while r < total do
    local l = vim.api.nvim_buf_get_lines(bufnr, r, r + 1, false)[1]
    local m = l and marker.parse(l, opts) or nil
    if not m then
      -- Non-marker continuation content (any indent) passes through
      -- unchanged without ending the run; too many consecutive blank lines
      -- end it.
      if not l then
        break
      end
      local continues
      continues, blanks = marker.is_continuation(l, blanks, max_blank)
      if not continues then
        break
      end
      out[#out + 1] = l
      r = r + 1
    elseif #m.indent < indent_w then
      break
    else
      blanks = 0
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

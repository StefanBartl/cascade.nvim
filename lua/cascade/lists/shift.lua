---@module 'cascade.lists.shift'
--- Step an ordered list item's number by a delta and let its neighbours of the
--- same level follow by the same delta -- without renumbering the list.
---
--- A full renumber (`cascade.lists.renumber`) forces every list back to
--- `1, 2, 3, ...` from its first item, which takes away the room a hand-made
--- list uses (a list that starts at 5, one with deliberate gaps). This keeps
--- that room: only the numbers it is asked to move move.
---
--- Two scopes, over the run of siblings (same indent, same marker kind) that
--- `cascade.lists.renumber` also works on:
---
---   * `"following"` -- the item under the cursor and every sibling AFTER it.
---     Items before it stay put. `x` on `2.` of `1. 2. 3.` gives `1. 1. 2.`.
---   * `"level"` -- every sibling of the level, before and after.
---
--- Deeper children and continuation lines are never touched. Digits move by
--- the delta (down to `0`); letters and Roman numerals move through the
--- alphabet / numeral sequence (`a)` -> `b)`, `iii.` -> `iv.`), case kept.
--- A step that would leave the representable range (below `a`/`i`, past `z`)
--- changes nothing at all and says why, rather than moving half the list.

local marker = require("cascade.lists.marker")
local renumber = require("cascade.lists.renumber")

local M = {}

---@internal
--- Marker text for `value`, or nil when `kind` cannot express it.
---@param kind CascadeMarkerKind
---@param value integer
---@param ref string  an existing marker of the run, for letter case
---@return string|nil
local function render_value(kind, value, ref)
  if kind == "digit" then
    if value < 0 then
      return nil
    end
    return tostring(value)
  end
  if value < 1 then
    return nil
  end
  -- A letter marker is ONE letter: `alpha.to_alpha(27)` is "aa", which the list
  -- parser no longer reads as a marker, so the item would silently leave the list.
  if kind == "ascii" and value > 26 then
    return nil
  end
  local s
  if kind == "ascii" then
    s = require("cascade.lists.alpha").to_alpha(value)
  else
    s = require("cascade.lists.roman").to_roman(value)
  end
  if not s then
    return nil
  end
  if ref == ref:upper() and ref ~= ref:lower() then
    return s:upper()
  end
  return s:lower()
end

---@internal
--- `ascii` and `roman` overlap on seven letters (c/d/i/l/m/v/x), and a bare
--- parse tries roman first -- so the `c)` of an "a) b) c)" list reads as Roman
--- 100. Two items are therefore the same run when their kinds are equal OR both
--- are letter kinds; the run's real kind is settled afterwards (see `collect`).
---@param a CascadeMarkerKind
---@param b CascadeMarkerKind
---@return boolean
local function same_family(a, b)
  if a == b then
    return true
  end
  return (a == "ascii" or a == "roman") and (b == "ascii" or b == "roman")
end

---@class CascadeShiftRun
---@field rows integer[]   # 0-based rows of the siblings, in buffer order
---@field items CascadeMarker[] # their parsed markers, same order
---@field kind CascadeMarkerKind

---@internal
--- The siblings (same indent, same kind) of the ordered item at `row0`,
--- scanned the way `renumber.run` scans its block: upward and downward across
--- deeper children and continuation content, ending at a shallower item, a
--- different kind at the same indent, or a real break.
---@param bufnr integer
---@param row0 integer
---@param opts CascadeListOpts
---@return CascadeShiftRun|nil
local function collect(bufnr, row0, opts)
  local function line_at(r)
    return vim.api.nvim_buf_get_lines(bufnr, r, r + 1, false)[1]
  end
  local cur_line = line_at(row0)
  local cur = cur_line and marker.parse(cur_line, opts) or nil
  if not cur or cur.kind == "unordered" then
    return nil
  end

  local indent_w = #cur.indent
  local max_blank = marker.blank_run(opts)
  local total = vim.api.nvim_buf_line_count(bufnr)

  local first = row0
  local blanks = 0
  while first - 1 >= 0 do
    local l = line_at(first - 1)
    local m = l and marker.parse(l, opts) or nil
    if m and #m.indent < indent_w then
      break
    elseif m and #m.indent == indent_w then
      if not same_family(m.kind, cur.kind) then
        break
      end
      first = first - 1
      blanks = 0
    elseif m then
      first = first - 1 -- deeper child, keep scanning
      blanks = 0
    elseif l then
      local continues
      continues, blanks = marker.is_continuation(l, blanks, max_blank)
      if not continues then
        break
      end
      first = first - 1
    else
      break
    end
  end

  local run = { rows = {}, items = {}, kind = cur.kind } ---@type CascadeShiftRun
  blanks = 0
  local r = first
  while r < total do
    local l = line_at(r)
    local m = l and marker.parse(l, opts) or nil
    if not l then
      break
    elseif not m then
      local continues
      continues, blanks = marker.is_continuation(l, blanks, max_blank)
      if not continues then
        break
      end
    elseif #m.indent < indent_w then
      break
    else
      blanks = 0
      if #m.indent == indent_w then
        if not same_family(m.kind, cur.kind) then
          break
        end
        run.rows[#run.rows + 1] = r
        run.items[#run.items + 1] = m
      end
    end
    r = r + 1
  end

  -- Settle the run's kind: one unambiguous letter item ("a", "b", "e") makes it
  -- an alphabetic list, otherwise Roman wins the tie like everywhere else; then
  -- re-read every item with that kind preferred so `c)` is the third letter.
  local kind = cur.kind
  if kind ~= "digit" then
    kind = "roman"
    for _, m in ipairs(run.items) do
      if m.kind == "ascii" then
        kind = "ascii"
        break
      end
    end
  end
  run.kind = kind
  for i, row in ipairs(run.rows) do
    run.items[i] = marker.parse(line_at(row), opts, kind) or run.items[i]
  end
  return run
end

--- Shift the ordered item at `row0` (and its siblings, per `scope`) by `delta`.
---@param bufnr integer
---@param row0 integer
---@param delta integer
---@param scope "following"|"level"
---@param opts CascadeListOpts
---@return boolean|nil changed  # nil: not on an ordered item; false: refused (out of range) or nothing to do
---@return string|nil err      # why it was refused
function M.shift(bufnr, row0, delta, scope, opts)
  local run = collect(bufnr, row0, opts)
  if not run then
    return nil
  end

  local from = 1
  if scope == "following" then
    for i, r in ipairs(run.rows) do
      if r >= row0 then
        from = i
        break
      end
    end
  end

  local plan = {} ---@type { row: integer, text: string }[]
  for i = from, #run.rows do
    local m = run.items[i]
    local value = renumber.value_of(run.kind, m.marker)
    if not value then
      return false, "cannot read the marker " .. m.marker
    end
    local want = render_value(run.kind, value + delta, m.marker)
    if not want then
      return false, ("cannot step %s by %+d: out of range for this kind of list"):format(m.marker, delta)
    end
    if want ~= m.marker then
      m.marker = want
      plan[#plan + 1] = { row = run.rows[i], text = marker.render(m) .. (m.text or "") }
    end
  end
  if #plan == 0 then
    return false
  end

  -- One contiguous write (see renumber.tree for why) from the first to the
  -- last changed row; the lines in between that did not change are re-set as is.
  local lo, hi = plan[1].row, plan[#plan].row
  local lines = vim.api.nvim_buf_get_lines(bufnr, lo, hi + 1, false)
  for _, p in ipairs(plan) do
    lines[p.row - lo + 1] = p.text
  end
  vim.api.nvim_buf_set_lines(bufnr, lo, hi + 1, false, lines)
  return true
end

--- Whether column `col0` of `line` sits on (or before) the list marker, i.e.
--- exactly where a native `<C-a>`/`<C-x>` would act on the marker's number.
---@param line string
---@param col0 integer
---@param opts CascadeListOpts
---@return boolean
function M.on_marker(line, col0, opts)
  local m = marker.parse(line, opts)
  if not m or m.kind == "unordered" then
    return false
  end
  return col0 <= #m.indent + #m.marker + #m.delim
end

return M

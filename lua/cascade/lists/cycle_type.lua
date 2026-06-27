---@module 'cascade.lists.cycle_type'
---@brief Cycle the cursor item's marker shape through `lists.cycle`.
---@description
--- Rotates a list item between configured marker templates, e.g.
--- `-` -> `*` -> `+` -> `1.` -> `a)` -> `I.`. Ordered targets carry the item's
--- current sequence value when possible (else start at 1); the checkbox and text
--- are preserved. Dot-repeatable via the central operatorfunc helper.

local marker = require("cascade.lists.marker")
local renumber = require("cascade.lists.renumber")
local roman = require("cascade.lists.roman")
local alpha = require("cascade.lists.alpha")

local M = {}

---@class CascadeTypeSpec
---@field kind CascadeMarkerKind
---@field delim string
---@field upper boolean
---@field bullet string|nil # for unordered

--- Parse a cycle template ("1.", "a)", "I.", "-") into a type spec.
--- Convention: `a/A` => ascii, `i/I` => roman, digits => digit, anything else
--- is treated as an unordered bullet character.
---@param tpl string
---@return CascadeTypeSpec
local function spec_of(tpl)
  local lead = tpl:sub(1, 1)
  local delim = tpl:sub(2)
  if lead:match("%d") then
    return { kind = "digit", delim = delim, upper = false }
  end
  local low = lead:lower()
  if low == "a" then
    return { kind = "ascii", delim = delim, upper = lead == lead:upper() }
  end
  if low == "i" then
    return { kind = "roman", delim = delim, upper = lead == lead:upper() }
  end
  return { kind = "unordered", delim = "", upper = false, bullet = lead }
end

--- Whether a parsed marker matches a type spec.
---@param m CascadeMarker
---@param spec CascadeTypeSpec
---@return boolean
local function matches(m, spec)
  if m.kind ~= spec.kind then
    return false
  end
  if spec.kind == "unordered" then
    return m.marker == spec.bullet
  end
  return m.delim == spec.delim
end

--- Current ordered value of a marker, or 1 for unordered/unknown.
---@param m CascadeMarker
---@return integer
local function value_of(m)
  if m.kind == "digit" then
    return tonumber(m.marker) or 1
  elseif m.kind == "ascii" then
    return alpha.to_int(m.marker) or 1
  elseif m.kind == "roman" then
    return roman.to_int(m.marker) or 1
  end
  return 1
end

--- Build a marker token for a target spec carrying `value`.
---@param spec CascadeTypeSpec
---@param value integer
---@return string
local function token_for(spec, value)
  if spec.kind == "unordered" then
    return spec.bullet
  end
  local s
  if spec.kind == "digit" then
    s = tostring(value)
  elseif spec.kind == "ascii" then
    s = alpha.to_alpha(value) or "a"
  else
    s = roman.to_roman(value) or "i"
  end
  if spec.kind ~= "digit" then
    s = spec.upper and s:upper() or s:lower()
  end
  return s
end

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

  -- Find current template index.
  local idx
  for i = 1, #cycle do
    if matches(m, spec_of(cycle[i])) then
      idx = i
      break
    end
  end
  if not idx then
    idx = 1 -- current shape not in cycle; jump to the first entry
  end

  local nxt = ((idx - 1 + dir) % #cycle) + 1
  local spec = spec_of(cycle[nxt])
  local value = value_of(m)

  local new_m = {
    indent = m.indent,
    kind = spec.kind,
    marker = token_for(spec, value),
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

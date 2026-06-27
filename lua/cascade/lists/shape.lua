---@module 'cascade.lists.shape'
---@brief Marker-shape specs: parse a template, match a marker, build a token.
---@description
--- Shared, pure helpers for everything that reasons about marker *shape* rather
--- than a concrete marker: `cycle_type` (per-line type cycle) and `transform`
--- (block/visual form rotation). A "template" is a short string like `1.`,
--- `a)`, `I.` or `-`; a "spec" is its decoded form.

local roman = require("cascade.lists.roman")
local alpha = require("cascade.lists.alpha")

local M = {}

---@class CascadeTypeSpec
---@field kind CascadeMarkerKind
---@field delim string
---@field upper boolean
---@field bullet string|nil # for unordered

--- Decode a template string into a type spec.
--- Convention: digits => digit, `a/A` => ascii, `i/I` => roman, any other
--- single leading character => unordered bullet.
---@param tpl string
---@return CascadeTypeSpec
function M.spec_of(tpl)
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
function M.matches(m, spec)
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
function M.value_of(m)
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
function M.token_for(spec, value)
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

return M

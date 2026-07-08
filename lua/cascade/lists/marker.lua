---@module 'cascade.lists.marker'
---@brief Pure list-marker parser, renderer and incrementer.
---@description
--- The heart of the list domain. `parse` turns a raw line into a `CascadeMarker`
--- (or nil), `render` rebuilds the marker prefix, and `advance` produces the next
--- marker for continuation (incrementing ordered markers, resetting checkboxes).
--- All functions are pure: they take strings/options and return values, never
--- touching the buffer. That keeps them trivially testable.

local patterns = require("cascade.core.patterns")
local roman = require("cascade.lists.roman")
local alpha = require("cascade.lists.alpha")

local M = {}

--- Split an optional `[x]` checkbox off the front of a body string.
---@param body string
---@return string|nil checkbox, string text
local function split_checkbox(body)
  local inner, rest = body:match("^%[(.)%]%s?(.*)$")
  if inner then
    return inner, rest
  end
  return nil, body
end

--- Parse a line into a marker description, or nil if it is not a list item.
---@param line string
---@param opts CascadeListOpts
---@return CascadeMarker|nil
function M.parse(line, opts)
  local indent = line:match("^(%s*)") or ""
  local rest = line:sub(#indent + 1)
  if rest == "" then
    return nil
  end

  local types = opts.types
  for i = 1, #types do
    local t = types[i]
    if t == "unordered" then
      local cls = patterns.unordered_class(opts.unordered_markers)
      local mk, after = rest:match("^(" .. cls .. ")%s(.*)$")
      if mk then
        local cb, text = split_checkbox(after)
        return { indent = indent, kind = "unordered", marker = mk, delim = "", checkbox = cb, text = text }
      end
    elseif t == "digit" then
      local num, d, after = rest:match("^(%d+)([%.%)])%s(.*)$")
      if num then
        local cb, text = split_checkbox(after)
        return { indent = indent, kind = "digit", marker = num, delim = d, checkbox = cb, text = text }
      end
    elseif t == "ascii" then
      local ch, d, after = rest:match("^(%a)([%.%)])%s(.*)$")
      if ch and alpha.to_int(ch) then
        local cb, text = split_checkbox(after)
        return { indent = indent, kind = "ascii", marker = ch, delim = d, checkbox = cb, text = text }
      end
    elseif t == "roman" then
      local rm, d, after = rest:match("^(%a+)([%.%)])%s(.*)$")
      if rm and roman.to_int(rm) then
        local cb, text = split_checkbox(after)
        return { indent = indent, kind = "roman", marker = rm, delim = d, checkbox = cb, text = text }
      end
    end
  end
  return nil
end

--- Whether a parsed item has no textual content (only a marker / checkbox).
---@param m CascadeMarker
---@return boolean
function M.is_empty(m)
  return m.text == nil or m.text:match("^%s*$") ~= nil
end

--- Whether `line` is empty or whitespace-only.
---@param line string
---@return boolean
function M.is_blank_line(line)
  return line:match("^%s*$") ~= nil
end

--- Whether a non-marker `line` is deeper-indented *continuation* content of a
--- list item at `ref_w` (e.g. a wrapped paragraph under a list entry) rather
--- than a real break in the list. Blank lines and lines at/above the item's
--- own indent always count as a real break.
---@param line string
---@param ref_w integer
---@return boolean
function M.is_continuation(line, ref_w)
  if M.is_blank_line(line) then
    return false
  end
  local w = #(line:match("^(%s*)") or "")
  return w > ref_w
end

--- Rebuild the marker prefix string (everything before the item text).
---@param m CascadeMarker
---@return string
function M.render(m)
  local out = { m.indent, m.marker, m.delim, " " }
  if m.checkbox ~= nil then
    out[#out + 1] = "[" .. m.checkbox .. "] "
  end
  return table.concat(out)
end

--- Apply the case shape of `ref` to `value` (lower/upper only — markers are
--- single-script alphabetic tokens).
---@param ref string
---@param value string
---@return string
local function match_case(ref, value)
  if ref == ref:upper() and ref ~= ref:lower() then
    return value:upper()
  end
  return value:lower()
end

--- Produce the marker for the *next* item in a list (for continuation).
--- Ordered markers are incremented; unordered keep their bullet; an existing
--- checkbox is reset to the first configured state; text is cleared.
---@param m CascadeMarker
---@param opts CascadeListOpts
---@return CascadeMarker
function M.advance(m, opts)
  local n = { indent = m.indent, kind = m.kind, delim = m.delim, text = "" }

  if m.kind == "digit" then
    n.marker = tostring((tonumber(m.marker) or 0) + 1)
  elseif m.kind == "ascii" then
    local idx = alpha.to_int(m.marker) or 0
    n.marker = match_case(m.marker, alpha.to_alpha(idx + 1) or m.marker)
  elseif m.kind == "roman" then
    local idx = roman.to_int(m.marker) or 0
    n.marker = match_case(m.marker, roman.to_roman(idx + 1) or m.marker)
  else
    n.marker = m.marker
  end

  if m.checkbox ~= nil then
    n.checkbox = opts.checkbox.states[1]
  end
  return n
end

return M

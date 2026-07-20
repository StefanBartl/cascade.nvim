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
---
--- The payload may be any single character (the classic `[x]`/`[-]`/`[?]`
--- markers) *or* a state listed in `opts.checkbox.states`, which is what allows
--- multi-byte states such as `[✅]`. Accepting a longer payload only when it is
--- explicitly configured is what keeps a Markdown link label — `- [see
--- docs](url)` — from parsing as a checkbox; a bare `[^%]]*` match would
--- swallow it.
---@param body string
---@param opts CascadeListOpts|nil
---@return string|nil checkbox, string text
local function split_checkbox(body, opts)
  local inner, rest = body:match("^%[([^%]]*)%]%s?(.*)$")
  if not inner then
    return nil, body
  end

  -- Exactly one byte: the historical behaviour of `^%[(.)%]`, preserved.
  if #inner == 1 then
    return inner, rest
  end

  local states = opts and opts.checkbox and opts.checkbox.states
  if states then
    for i = 1, #states do
      if states[i] == inner then
        return inner, rest
      end
    end
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
        local cb, text = split_checkbox(after, opts)
        return { indent = indent, kind = "unordered", marker = mk, delim = "", checkbox = cb, text = text }
      end
    elseif t == "digit" then
      local num, d, after = rest:match("^(%d+)([%.%)])%s(.*)$")
      if num then
        local cb, text = split_checkbox(after, opts)
        return { indent = indent, kind = "digit", marker = num, delim = d, checkbox = cb, text = text }
      end
    elseif t == "ascii" then
      local ch, d, after = rest:match("^(%a)([%.%)])%s(.*)$")
      if ch and alpha.to_int(ch) then
        local cb, text = split_checkbox(after, opts)
        return { indent = indent, kind = "ascii", marker = ch, delim = d, checkbox = cb, text = text }
      end
    elseif t == "roman" then
      local rm, d, after = rest:match("^(%a+)([%.%)])%s(.*)$")
      if rm and roman.to_int(rm) then
        local cb, text = split_checkbox(after, opts)
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

--- Default for how many *consecutive* blank lines are tolerated inside a list
--- block before they count as a real break. `0` means any blank line ends the
--- block — a plain, predictable default that avoids "run-on" numbering across
--- visually separate lists. It can be raised via `lists.renumber.blank_break`
--- (e.g. `1` for the CommonMark "loose list" reading, where a single blank line
--- between items still belongs to one list).
M.MAX_BLANK_RUN = 0

--- Whether a non-marker `line` continues the running block instead of
--- breaking it: any non-blank line always does (indentation doesn't matter);
--- a blank line does too, as long as `blanks_before` hasn't already reached
--- `max_blank_run`.
---@param line string
---@param blanks_before integer # consecutive blank lines seen immediately before `line`.
---@param max_blank_run integer|nil # tolerated consecutive blanks; defaults to `M.MAX_BLANK_RUN`.
---@return boolean continues, integer blanks_after
function M.is_continuation(line, blanks_before, max_blank_run)
  if not M.is_blank_line(line) then
    return true, 0
  end
  local n = blanks_before + 1
  return n <= (max_blank_run or M.MAX_BLANK_RUN), n
end

--- The configured consecutive-blank-line tolerance for a list block, read from
--- `opts.renumber.blank_break`, falling back to `M.MAX_BLANK_RUN`.
---@param opts CascadeListOpts
---@return integer
function M.blank_run(opts)
  local r = opts.renumber
  if type(r) == "table" and type(r.blank_break) == "number" then
    return r.blank_break
  end
  return M.MAX_BLANK_RUN
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

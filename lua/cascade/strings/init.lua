---@module 'cascade.strings'
--- The strings domain: advance a string literal's *kind* one step when its
--- contents ask for it. Type `${` inside a JS/TS `"string"` and it becomes a
--- `` `template string` ``; delete the last `${…}` and it turns back. Type
--- `{name}` inside a Python `"string"` and it becomes an `f"string"`; a Lua
--- `"%s"` literal becomes `("%s"):format()`. The same detect -> advance
--- pattern as the rest of cascade, applied to the quotes around the cursor
--- rather than the token under it.
---
--- This is the one domain that runs from an autocmd rather than a key: the
--- conversion happens after `InsertLeave`/`TextChanged` (see
--- `bindings/autocmds.lua`), deferred one tick so other autocmds finish
--- first. It is Tree-sitter based by necessity -- "am I inside a string, and
--- where does it start and end" is not a line-scan question -- and every
--- Tree-sitter call is pcall-guarded: no parser for the buffer means no
--- conversion, never an error.
---
--- Guards, all inherited from the idea's origin (nvim-puppeteer): an empty
--- literal is left alone (the user is about to type into it), anything
--- longer than `max_characters` is left alone (a broken parse can produce a
--- "string" spanning half the file), and a Lua literal that looks like a
--- pattern (`%s+`, `%d`, `%w`) or is an argument to `match`/`find`/`gsub`/
--- `gmatch`/`string.format` is never touched.

local config = require("cascade.config")

local M = {}

---@internal
---@return CascadeStringsOpts
local function opts()
  return config.get("strings")
end

---@internal
---Replace the text of `node` in `bufnr`, joined to the previous undo step so
---the conversion does not become its own `u` stop.
---@param bufnr integer
---@param node TSNode
---@param text string
local function replace_node(bufnr, node, text)
  local srow, scol, erow, ecol = node:range()
  pcall(vim.cmd.undojoin)
  vim.api.nvim_buf_set_text(bufnr, srow, scol, erow, ecol, vim.split(text, "\n", { plain = true }))
end

---@internal
---The innermost node at the cursor of `bufnr`'s window, after a parse.
---@param bufnr integer
---@return TSNode|nil
local function node_at_cursor(bufnr)
  local ok, node = pcall(function()
    local parser = vim.treesitter.get_parser(bufnr)
    if not parser then
      return nil
    end
    parser:parse()
    local win = vim.fn.bufwinid(bufnr)
    if win == -1 then
      return nil
    end
    local cur = vim.api.nvim_win_get_cursor(win)
    return vim.treesitter.get_node({ bufnr = bufnr, pos = { cur[1] - 1, cur[2] } })
  end)
  if ok then
    return node
  end
  return nil
end

---@internal
---@param bufnr integer
---@param node TSNode
---@return string
local function node_text(bufnr, node)
  return vim.treesitter.get_node_text(node, bufnr)
end

---@internal
---Whether a literal's text passes the size guards.
---@param text string
---@return boolean
local function sized(text)
  local max = opts().max_characters
  return text ~= "" and #text <= (type(max) == "number" and max or 200)
end

-- ---------------------------------------------------------------- JS/TS

---Convert the JS/TS string at the cursor: `"…${x}…"` -> `` `…${x}…` ``,
---and a template string with no `${}` and no newline back to a plain quoted
---string (tagged templates are left alone).
---@param bufnr integer|nil
---@return boolean changed
function M.template_string(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local node = node_at_cursor(bufnr)
  if not node then
    return false
  end
  local typ = node:type()
  if typ == "string_fragment" or typ == "escape_sequence" or typ == "template_substitution" then
    node = node:parent()
  end
  if not node then
    return false
  end
  typ = node:type()
  if typ ~= "string" and typ ~= "template_string" then
    return false
  end
  local text = node_text(bufnr, node)
  if not sized(text) then
    return false
  end

  -- Text, not node type: the tree is not always re-parsed by the time the
  -- autocmd fires, so the quotes are what is trusted.
  local is_template = text:find("^`.*`$") ~= nil
  local parent = node:parent()
  local is_tagged = parent ~= nil and parent:type() == "call_expression"
  local multiline = text:find("[\n\r]") ~= nil
  local has_braces = text:find("%${.-}") ~= nil

  if not is_template and (has_braces or multiline) then
    replace_node(bufnr, node, "`" .. text:sub(2, -2) .. "`")
    return true
  end
  if is_template and not (has_braces or multiline or is_tagged) then
    local quote = opts().quote == "'" and "'" or '"'
    replace_node(bufnr, node, quote .. text:sub(2, -2) .. quote)
    return true
  end
  return false
end

-- ---------------------------------------------------------------- Python

---Convert the Python string at the cursor: `"…{x}…"` -> `f"…{x}…"`, and an
---f-string with no braces back. `{}`, `{0}`, `{, }` do not count as a
---placeholder (they are set/dict/format-index syntax too often).
---@param bufnr integer|nil
---@return boolean changed
function M.python_fstring(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local node = node_at_cursor(bufnr)
  if not node then
    return false
  end
  local str
  local typ = node:type()
  if typ == "string" then
    str = node
  elseif typ:find("^string_") or typ == "interpolation" then
    str = node:parent()
  elseif typ == "escape_sequence" then
    str = node:parent() and node:parent():parent()
  else
    return false
  end
  if not str or str:type() ~= "string" then
    return false
  end
  local text = node_text(bufnr, str)
  if not sized(text) then
    return false
  end

  local is_f = text:find("^[rR]?[fF]") ~= nil
  local is_t = text:find("^[rR]?[tT]") ~= nil
  local has_braces = text:find("{.-[^%d,%s].-}") ~= nil

  if not is_f and not is_t and has_braces then
    replace_node(bufnr, str, "f" .. text)
    return true
  end
  if is_f and not has_braces then
    replace_node(bufnr, str, (text:gsub("^([rR]?)[fF]", "%1", 1)))
    return true
  end
  return false
end

-- ---------------------------------------------------------------- Lua

local PATTERN_METHODS = { match = true, gmatch = true, find = true, gsub = true, format = true }

---@internal
---Whether `str` is an argument of a `:match`/`.find`/`string.format`-style
---call, where `%s` means a pattern class or is already being formatted.
---@param bufnr integer
---@param str TSNode
---@return boolean
local function lua_pattern_context(bufnr, str)
  local args = str:parent()
  if not args or args:type() ~= "arguments" then
    return false
  end
  local call = args:parent()
  if not call or call:type() ~= "function_call" then
    return false
  end
  local callee = call:child(0)
  if not callee then
    return false
  end
  local name = node_text(bufnr, callee):match("[%w_]+$")
  return name ~= nil and PATTERN_METHODS[name] == true
end

---Convert the Lua string at the cursor: a literal with `%s`/`%d`/`%q`/…
---placeholders becomes `("…"):format()` with the cursor placed inside the
---parentheses, and a `("…"):format()` whose literal lost its placeholders
---collapses back to the literal. Pattern-looking literals and arguments of
---`match`/`find`/`gsub`/`gmatch`/`format` are left alone.
---@param bufnr integer|nil
---@return boolean changed
function M.lua_format(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local node = node_at_cursor(bufnr)
  if not node then
    return false
  end
  local str
  local typ = node:type()
  if typ == "string" then
    str = node
  elseif typ == "string_content" then
    str = node:parent()
  elseif typ == "escape_sequence" then
    str = node:parent() and node:parent():parent()
  else
    return false
  end
  if not str or str:type() ~= "string" then
    return false
  end
  local text = node_text(bufnr, str)
  if not sized(text) then
    return false
  end
  if text:find("%%[waudglpfb]") or text:find("%%s[*+-]") or lua_pattern_context(bufnr, str) then
    return false
  end

  -- `%s`/`%q` and the `%06X` hex idiom, the placeholders that are not also
  -- pattern classes (`%d`, `%x`, ... are, and were rejected above).
  local has_placeholder = text:find("%%[sq]") ~= nil or text:find("%%06[Xx]") ~= nil
  local parent = str:parent()
  local is_format = parent ~= nil and parent:type() == "parenthesized_expression"

  if has_placeholder and not is_format then
    replace_node(bufnr, str, "(" .. text .. "):format()")
    local win = vim.fn.bufwinid(bufnr)
    if win ~= -1 then
      local erow, ecol = str:end_()
      -- `str` still describes the old range; the new text is that plus
      -- `(`…`):format()` -- the closing paren sits 1 + 9 columns further.
      pcall(vim.api.nvim_win_set_cursor, win, { erow + 1, ecol + 1 + 9 })
    end
    return true
  end
  if is_format and not has_placeholder then
    -- `(` str `)` is the parenthesized_expression; its parent is the method
    -- index `(…):format`, whose parent is the call `(…):format(…)`.
    local index = parent:parent()
    local call = index and index:parent()
    if not call or call:type() ~= "function_call" then
      return false
    end
    local call_text = node_text(bufnr, call)
    local stripped = call_text:match("^%((.*)%):format%(.*%)$")
    if not stripped then
      return false
    end
    replace_node(bufnr, call, stripped)
    return true
  end
  return false
end

-- ---------------------------------------------------------------- dispatch

---@internal
---@param fts string[]|nil
---@param ft string
---@return boolean
local function ft_in(fts, ft)
  for _, f in ipairs(fts or {}) do
    if f == ft then
      return true
    end
  end
  return false
end

---Which converter applies to `ft`, or nil.
---@param ft string
---@return (fun(bufnr: integer|nil): boolean)|nil
---@return string|nil feature
function M.converter_for(ft)
  local o = opts()
  if not o.enable then
    return nil, nil
  end
  local f = o.features or {}
  if f.template and ft_in(o.template_filetypes, ft) then
    return M.template_string, "template"
  end
  if f.fstring and ft_in(o.fstring_filetypes, ft) then
    return M.python_fstring, "fstring"
  end
  if f.lua_format and ft_in(o.lua_format_filetypes, ft) then
    return M.lua_format, "lua_format"
  end
  return nil, nil
end

---Every filetype some enabled converter attaches to.
---@return string[]
function M.filetypes()
  local o = opts()
  local out, seen = {}, {}
  if not o.enable then
    return out
  end
  local f = o.features or {}
  local lists = {
    { f.template, o.template_filetypes },
    { f.fstring, o.fstring_filetypes },
    { f.lua_format, o.lua_format_filetypes },
  }
  for _, pair in ipairs(lists) do
    if pair[1] then
      for _, ft in ipairs(pair[2] or {}) do
        if not seen[ft] then
          seen[ft] = true
          out[#out + 1] = ft
        end
      end
    end
  end
  return out
end

---Whether the domain is active for `bufnr`: enabled, a converter for its
---filetype, a real file buffer, and not switched off per buffer.
---@param bufnr integer|nil
---@return boolean
function M.active(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(bufnr) or vim.bo[bufnr].buftype ~= "" then
    return false
  end
  if vim.b[bufnr].cascade_strings == false then
    return false
  end
  return M.converter_for(vim.bo[bufnr].filetype) ~= nil
end

---Run the converter for `bufnr`'s filetype at the cursor, if the domain is
---active there.
---@param bufnr integer|nil
---@return boolean changed
function M.convert(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not M.active(bufnr) then
    return false
  end
  local fn = M.converter_for(vim.bo[bufnr].filetype)
  if not fn then
    return false
  end
  local ok, changed = pcall(fn, bufnr)
  return ok and changed == true
end

---Per-buffer switch. `nil` toggles.
---@param on boolean|nil
---@param bufnr integer|nil
---@return boolean now_on
function M.set_buffer(on, bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if on == nil then
    on = vim.b[bufnr].cascade_strings == false
  end
  if on then
    vim.b[bufnr].cascade_strings = nil
  else
    vim.b[bufnr].cascade_strings = false
  end
  return on
end

return M

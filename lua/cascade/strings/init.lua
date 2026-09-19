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
  local lines = vim.split(text, "\n", { plain = true })
  -- Both `:undojoin` and the edit itself run inside `bufnr`'s own window
  -- context: `:undojoin` joins the NEXT change of whatever buffer is
  -- CURRENT when it runs, and by the time this fires (from a 1ms-deferred
  -- callback) that may no longer be `bufnr` -- an unrelated edit to a
  -- different buffer in between would otherwise splice this conversion
  -- into THAT buffer's undo history instead of the edit that triggered it.
  vim.api.nvim_buf_call(bufnr, function()
    pcall(vim.cmd.undojoin)
    vim.api.nvim_buf_set_text(bufnr, srow, scol, erow, ecol, lines)
  end)
end

---@internal
---The window to read/write the cursor in for `bufnr`: `winid` when it is
---still valid and still shows `bufnr` (the caller's own record of which
---window was actually being edited, captured synchronously at trigger
---time -- see bindings/autocmds.lua); the current window when THAT shows
---`bufnr`; `vim.fn.bufwinid(bufnr)` -- the first window showing it, not
---necessarily the right one -- only as a last resort.
---@param bufnr integer
---@param winid integer|nil
---@return integer|nil
local function resolve_win(bufnr, winid)
  if winid and vim.api.nvim_win_is_valid(winid) and vim.api.nvim_win_get_buf(winid) == bufnr then
    return winid
  end
  local cur = vim.api.nvim_get_current_win()
  if vim.api.nvim_win_get_buf(cur) == bufnr then
    return cur
  end
  local w = vim.fn.bufwinid(bufnr)
  return w ~= -1 and w or nil
end

---@internal
---The innermost node at the cursor of `bufnr`, after a parse.
---@param bufnr integer
---@param winid integer|nil  see `resolve_win`
---@return TSNode|nil
local function node_at_cursor(bufnr, winid)
  local ok, node = pcall(function()
    local parser = vim.treesitter.get_parser(bufnr)
    if not parser then
      return nil
    end
    parser:parse()
    local win = resolve_win(bufnr, winid)
    if not win then
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
---@param winid integer|nil
---@return boolean changed
function M.template_string(bufnr, winid)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local node = node_at_cursor(bufnr, winid)
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
---@param winid integer|nil
---@return boolean changed
function M.python_fstring(bufnr, winid)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local node = node_at_cursor(bufnr, winid)
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
---@internal
---Walk up from `node` to the nearest enclosing `chunk`/`block` -- the
---function body or file `node` sits in, regardless of how many
---`variable_declaration`/`if_statement`/... wrappers are in between.
---@param node TSNode
---@return TSNode|nil
local function enclosing_block(node)
  local n = node:parent()
  while n do
    local t = n:type()
    if t == "chunk" or t == "block" then
      return n
    end
    n = n:parent()
  end
  return nil
end

---@internal
---The callee's trailing method/function name for `call` (a `function_call`
---node) -- covers `x:METHOD(...)`, `mod.METHOD(...)` and a bare
---`METHOD(...)` alike via a plain text-suffix match, the same way the
---direct-argument check above resolves it, rather than branching on the
---callee's exact node shape.
---@param bufnr integer
---@param call TSNode
---@return string|nil
local function call_method_name(bufnr, call)
  local callee = call:child(0)
  if not callee then
    return nil
  end
  return node_text(bufnr, callee):match("[%w_]+$")
end

---@internal
---Whether `name` is used, anywhere inside `scope`, either as the RECEIVER
---of a pattern method (`name:match(...)`) or as a direct ARGUMENT to one
---(`s:find(name)`, `string.gsub(s, name, r)`) -- the two shapes a Lua
---pattern kept in a named local actually gets used in. A plain tree walk,
---not real dataflow: a pattern reached through a second alias, or built up
---across more than one assignment, is still invisible to it -- narrower
---than the case this exists to catch, on purpose (a false negative here
---just means a pattern-looking literal converts when it should not have; a
---false positive would leave a real format string unconverted, which is
---the safer failure).
---@param bufnr integer
---@param scope TSNode
---@param name string
---@return boolean
local function used_as_pattern_method(bufnr, scope, name)
  for node in scope:iter_children() do
    if node:type() == "function_call" then
      local mname = call_method_name(bufnr, node)
      if mname and PATTERN_METHODS[mname] == true then
        local callee = node:child(0)
        -- Receiver: `name:METHOD(...)`.
        if callee and callee:type() == "method_index_expression" then
          local obj = callee:child(0)
          if obj and obj:type() == "identifier" and node_text(bufnr, obj) == name then
            return true
          end
        end
        -- Argument: `METHOD(..., name, ...)`.
        for arg_list in node:iter_children() do
          if arg_list:type() == "arguments" then
            for a in arg_list:iter_children() do
              if a:type() == "identifier" and node_text(bufnr, a) == name then
                return true
              end
            end
          end
        end
      end
    end
    if used_as_pattern_method(bufnr, node, name) then
      return true
    end
  end
  return false
end

---@internal
---Whether `str` is an argument of a `:match`/`.find`/`string.format`-style
---call, where `%s` means a pattern class or is already being formatted --
---either directly (`s:match("...")`), or one hop removed, through a local
---variable the literal was just assigned to (`local pat = "..."` later
---used as `s:match(pat)` anywhere in the same function/file).
---@param bufnr integer
---@param str TSNode
---@return boolean
local function lua_pattern_context(bufnr, str)
  local args = str:parent()
  if args and args:type() == "arguments" then
    local call = args:parent()
    if call and call:type() == "function_call" then
      local callee = call:child(0)
      if callee then
        local name = node_text(bufnr, callee):match("[%w_]+$")
        if name ~= nil and PATTERN_METHODS[name] == true then
          return true
        end
      end
    end
  end

  -- Not a direct call argument: if this literal is the sole initializer of
  -- a plain or `local` variable, check whether that name is later used as
  -- a pattern-method argument anywhere in the enclosing function/file.
  local list = str:parent()
  if list and list:type() == "expression_list" then
    local stmt = list:parent()
    if stmt and stmt:type() == "assignment_statement" then
      local names = stmt:child(0)
      local scope = enclosing_block(stmt)
      if names and names:type() == "variable_list" and scope then
        for i = 0, names:named_child_count() - 1 do
          local nm = names:named_child(i)
          if nm and nm:type() == "identifier" and used_as_pattern_method(bufnr, scope, node_text(bufnr, nm)) then
            return true
          end
        end
      end
    end
  end
  return false
end

---Convert the Lua string at the cursor: a literal with `%s`/`%d`/`%q`/…
---placeholders becomes `("…"):format()` with the cursor placed inside the
---parentheses, and a `("…"):format()` whose literal lost its placeholders
---collapses back to the literal. Pattern-looking literals and arguments of
---`match`/`find`/`gsub`/`gmatch`/`format` are left alone.
---@param bufnr integer|nil
---@param winid integer|nil
---@return boolean changed
function M.lua_format(bufnr, winid)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local node = node_at_cursor(bufnr, winid)
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
    local prefix, suffix = "(", "):format()"
    local srow = str:start()
    local erow, ecol = str:end_()
    replace_node(bufnr, str, prefix .. text .. suffix)
    local win = resolve_win(bufnr, winid)
    if win then
      -- `str` still describes the OLD (pre-edit) range. The suffix always
      -- lands right after the old end column; the prefix shifts that SAME
      -- column too only when the literal is single-line (srow == erow) --
      -- for a multi-line long-bracket string the `(` was inserted on an
      -- EARLIER row and does not affect the closing row's columns at all.
      -- Either way the target is one column back from the final `)`, i.e.
      -- inside the still-empty format() parens.
      local col = ecol + #suffix - 1
      if erow == srow then
        col = col + #prefix
      end
      pcall(vim.api.nvim_win_set_cursor, win, { erow + 1, col })
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

-- TESTS/strings_spec.lua — the strings domain: JS/TS template strings,
-- Python f-strings, Lua format strings, and the per-buffer switch. Each
-- language block is skipped when its Tree-sitter parser is not available in
-- the test Neovim; the Lua block always runs (the parser is bundled).
---@diagnostic disable: missing-fields, need-check-nil, param-type-mismatch

return function(H)
  local eq = H.eq
  local ok = H.ok
  local strings = require("cascade.strings")
  local config = require("cascade.config")

  config.setup({ strings = { features = { lua_format = true } } })

  -- `language.add` answers true on Neovim 0.12 even with no parser file on
  -- the runtimepath, so the file is what is checked.
  local function has_parser(lang)
    return #vim.api.nvim_get_runtime_file("parser/" .. lang .. ".*", false) > 0
  end

  ---@param ft string
  ---@param line string
  ---@param col integer  0-based cursor column
  local function buffer_with(ft, line, col)
    local buf = H.editable(ft)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { line })
    vim.api.nvim_win_set_cursor(0, { 1, col })
    return buf
  end

  local function line1(buf)
    return vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1]
  end

  -- ============================================================ filetypes()

  local fts = strings.filetypes()
  ok(vim.tbl_contains(fts, "javascript"), "filetypes: javascript attached")
  ok(vim.tbl_contains(fts, "python"), "filetypes: python attached")
  ok(vim.tbl_contains(fts, "lua"), "filetypes: lua attached once enabled")
  eq(#fts, #vim.fn.uniq(vim.fn.sort(vim.deepcopy(fts))), "filetypes: no duplicates")
  eq(strings.converter_for("markdown"), nil, "converter_for: none for markdown")

  -- ============================================================ Lua

  local buf = buffer_with("lua", 'local s = "%s items"', 12)
  eq(strings.lua_format(buf), true, "lua: placeholder literal converts")
  eq(line1(buf), 'local s = ("%s items"):format()', "lua: wrapped in (…):format()")
  eq(vim.api.nvim_win_get_cursor(0)[2], 30, "lua: cursor inside the format() parens")

  -- Back: the literal lost its placeholder.
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'local s = ("items"):format()' })
  vim.api.nvim_win_set_cursor(0, { 1, 14 })
  eq(strings.lua_format(buf), true, "lua: placeholder-less format() collapses")
  eq(line1(buf), 'local s = "items"', "lua: back to the plain literal")

  -- Pattern-looking literals and pattern-method arguments are left alone.
  buf = buffer_with("lua", 'local m = s:match("%s+")', 20)
  eq(strings.lua_format(buf), false, "lua: pattern literal untouched")
  buf = buffer_with("lua", 'local m = string.format("%s", n)', 26)
  eq(strings.lua_format(buf), false, "lua: string.format argument untouched")
  buf = buffer_with("lua", 'local s = ""', 11)
  eq(strings.lua_format(buf), false, "lua: empty literal untouched")

  -- convert() routes by filetype and respects the per-buffer switch.
  buf = buffer_with("lua", 'x = "%d"', 5)
  eq(strings.lua_format(buf), false, "lua: %d is a pattern class, not a placeholder")
  buf = buffer_with("lua", 'x = "%s"', 5)
  strings.set_buffer(false, buf)
  eq(strings.active(buf), false, "active: off per buffer")
  eq(strings.convert(buf), false, "convert: no-op when switched off")
  eq(strings.set_buffer(nil, buf), true, "set_buffer: toggle back on")
  eq(strings.convert(buf), true, "convert: routes to lua_format")
  eq(line1(buf), 'x = ("%s"):format()', "convert: converted")

  -- A scratch buffer never converts.
  local scratch = H.scratch("lua")
  eq(strings.active(scratch), false, "active: nofile buffer is inactive")

  -- ============================================================ JS/TS

  if has_parser("javascript") then
    buf = buffer_with("javascript", 'const s = "hi ${name}";', 15)
    eq(strings.template_string(buf), true, "js: ${} converts to a template string")
    eq(line1(buf), "const s = `hi ${name}`;", "js: backticks")

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "const s = `hi there`;" })
    vim.api.nvim_win_set_cursor(0, { 1, 14 })
    eq(strings.template_string(buf), true, "js: template without ${} converts back")
    eq(line1(buf), 'const s = "hi there";', "js: double quotes by default")

    config.setup({ strings = { quote = "'" } })
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "const s = `hi there`;" })
    vim.api.nvim_win_set_cursor(0, { 1, 14 })
    strings.template_string(buf)
    eq(line1(buf), "const s = 'hi there';", "js: quote option honoured")
    config.setup({ strings = { features = { lua_format = true } } })

    buf = buffer_with("javascript", "const s = tag`hi there`;", 17)
    eq(strings.template_string(buf), false, "js: tagged template untouched")
    buf = buffer_with("javascript", 'const s = "";', 11)
    eq(strings.template_string(buf), false, "js: empty string untouched")
  else
    print("      (skip) no javascript parser")
  end

  -- ============================================================ Python

  if has_parser("python") then
    buf = buffer_with("python", 's = "hi {name}"', 8)
    eq(strings.python_fstring(buf), true, "py: {name} converts to an f-string")
    eq(line1(buf), 's = f"hi {name}"', "py: f prefix")

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 's = f"hi there"' })
    vim.api.nvim_win_set_cursor(0, { 1, 9 })
    eq(strings.python_fstring(buf), true, "py: f-string without braces converts back")
    eq(line1(buf), 's = "hi there"', "py: prefix dropped")

    buf = buffer_with("python", 's = "{}"', 6)
    eq(strings.python_fstring(buf), false, "py: bare {} is not a placeholder")
    buf = buffer_with("python", 's = "{0}"', 6)
    eq(strings.python_fstring(buf), false, "py: {0} is not a placeholder")
  else
    print("      (skip) no python parser")
  end

  -- ============================================================ autocmd wiring

  require("cascade").setup({ strings = { features = { lua_format = true } } })
  local autocmds = vim.api.nvim_get_autocmds({ group = "cascade_strings" })
  ok(#autocmds >= 1, "autocmds: FileType trigger registered")
  buf = buffer_with("lua", 'x = "%s"', 5)
  vim.api.nvim_exec_autocmds("FileType", { pattern = "lua" })
  local local_cmds = vim.api.nvim_get_autocmds({ buffer = buf, event = { "InsertLeave", "TextChanged" } })
  ok(#local_cmds >= 2, "autocmds: buffer-local triggers bound on FileType")

  -- Off entirely: nothing registers.
  require("cascade").setup({ strings = { enable = false } })
  eq(#strings.filetypes(), 0, "disabled: no filetypes")
  eq(#vim.api.nvim_get_autocmds({ group = "cascade_strings" }), 0, "disabled: no FileType trigger")
  require("cascade").setup({})
end

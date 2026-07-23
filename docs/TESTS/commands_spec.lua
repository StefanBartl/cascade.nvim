-- docs/TESTS/commands_spec.lua — user commands exist and feature toggles gate.
---@diagnostic disable: missing-fields, need-check-nil, param-type-mismatch

return function(H)
  local eq = H.eq
  local eq_lines = H.eq_lines
  local cfg = require("cascade.config")
  local cascade = require("cascade")

  -- the :Cascade verb (composer-built) exists after setup, with every
  -- subcommand reachable and completed
  cascade.setup({})
  eq(vim.fn.exists(":Cascade"), 2, ":Cascade defined")
  local subs = vim.fn.getcompletion("Cascade ", "cmdline")
  table.sort(subs)
  eq(table.concat(subs, ","), "dedent,indent,renumber,reverse,rotate,sort,strip",
    ":Cascade completes every subcommand")

  -- lists.format's hanging-indent options apply via their own FileType
  -- autocmd, independent of the keymaps.preset switch (regression: they used
  -- to piggyback on the keymap-preset-only autocmd and never fired for the
  -- default, non-preset setup — the common case).
  cfg.setup({})
  local fmt_buf = H.scratch()
  vim.bo[fmt_buf].filetype = "markdown"
  local format = require("cascade.lists.format")
  eq(vim.bo[fmt_buf].formatlistpat, format.list_pat(cfg.get("lists")), "FileType autocmd sets formatlistpat without preset")
  local has_n = vim.bo[fmt_buf].formatoptions:find("n", 1, true) ~= nil
  eq(has_n, true, "FileType autocmd adds 'n' to formatoptions without keymaps.preset")

  -- feature toggles: disabling a feature makes its action a no-op.
  cfg.setup({ lists = { features = { checkbox = false, sort = false } } })
  local lopts2 = cfg.get("lists")
  eq(lopts2.features.checkbox, false, "checkbox feature off")
  eq(lopts2.features.cycle_type, true, "unspecified feature stays on")

  local buf = H.scratch("markdown")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "- task" })
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  cascade.toggle_checkbox()
  vim.api.nvim_feedkeys("", "x", false)
  eq(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1], "- task", "disabled checkbox = no-op")

  cfg.setup({})

  -- visual indent/dedent must keep the selection active so a chained
  -- <A-Right>/<A-Left> works without re-selecting (regression: the previous
  -- reselect used :normal! which silently exits Visual mode).
  vim.g.mapleader = " " -- must be set before setup(): <Leader> in a mapping's lhs resolves at bind time.
  cascade.setup({ keymaps = { preset = true } })
  local ebuf = H.editable("markdown")
  vim.bo[ebuf].expandtab = true
  vim.bo[ebuf].shiftwidth = 2
  vim.api.nvim_buf_set_lines(ebuf, 0, -1, false, { "1. a", "2. b", "3. c", "4. d" })
  vim.api.nvim_win_set_cursor(0, { 2, 0 })

  vim.api.nvim_feedkeys(vim.keycode("Vj<A-Right>"), "mtx", false)
  eq(vim.fn.mode(), "V", "selection survives one visual indent")
  local l1 = vim.api.nvim_buf_get_lines(ebuf, 0, -1, false)
  eq(l1[2], "  1. b", "visual indent: first shifted line")
  eq(l1[3], "  2. c", "visual indent: second shifted line")

  -- second <A-Right> WITHOUT reselecting: must indent further.
  vim.api.nvim_feedkeys(vim.keycode("<A-Right>"), "mtx", false)
  eq(vim.fn.mode(), "V", "selection survives chained visual indent")
  local l2 = vim.api.nvim_buf_get_lines(ebuf, 0, -1, false)
  eq(l2[2], "    1. b", "chained visual indent: shifts one level deeper")
  eq(l2[3], "    2. c", "chained visual indent: both lines")

  -- two <A-Left> WITHOUT reselecting: back to the original level/numbering.
  vim.api.nvim_feedkeys(vim.keycode("<A-Left>"), "mtx", false)
  vim.api.nvim_feedkeys(vim.keycode("<A-Left>"), "mtx", false)
  eq(vim.fn.mode(), "V", "selection survives chained visual dedent")
  local l3 = vim.api.nvim_buf_get_lines(ebuf, 0, -1, false)
  eq(l3[2], "2. b", "chained visual dedent back to original")
  eq(l3[3], "3. c", "chained visual dedent back to original")

  vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "mtx", false)

  -- quick-toggle keys (<A-->, <A-*>, <A-0>, <A-c>) work on a real Visual
  -- (charwise) and Visual-line selection, not just Normal mode, and keep
  -- the selection active afterwards (regression: it used to be dropped via
  -- a bare <Esc>, so a chained toggle needed re-selecting). Each block
  -- opens with <Esc> since the previous block leaves its own selection
  -- active on stale text.
  vim.api.nvim_buf_set_lines(ebuf, 0, -1, false, { "one", "two", "three" })
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  vim.api.nvim_feedkeys(vim.keycode("<Esc>V2j<A-->"), "mtx", false)
  eq_lines(
    vim.api.nvim_buf_get_lines(ebuf, 0, -1, false),
    { "- one", "- two", "- three" },
    "V + <A--> bullet-toggles the whole selection"
  )
  eq(vim.fn.mode(), "V", "selection survives <A--> bullet toggle")

  vim.api.nvim_buf_set_lines(ebuf, 0, -1, false, { "one", "two", "three" })
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  vim.api.nvim_feedkeys(vim.keycode("<Esc>v2j$<A-*>"), "mtx", false)
  eq_lines(
    vim.api.nvim_buf_get_lines(ebuf, 0, -1, false),
    { "* one", "* two", "* three" },
    "v (charwise) + <A-*> star-toggles the whole selection"
  )
  eq(vim.fn.mode(), "V", "selection survives <A-*> star toggle")

  vim.api.nvim_buf_set_lines(ebuf, 0, -1, false, { "one", "two", "three" })
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  vim.api.nvim_feedkeys(vim.keycode("<Esc>V2j<A-0>"), "mtx", false)
  eq_lines(
    vim.api.nvim_buf_get_lines(ebuf, 0, -1, false),
    { "1. one", "2. two", "3. three" },
    "V + <A-0> numbers the whole selection"
  )
  eq(vim.fn.mode(), "V", "selection survives <A-0> number toggle")

  -- second <A-0> WITHOUT reselecting: strips the numbering back off, proving
  -- the surviving selection is chainable (same convention as visual indent).
  vim.api.nvim_feedkeys(vim.keycode("<A-0>"), "mtx", false)
  eq_lines(
    vim.api.nvim_buf_get_lines(ebuf, 0, -1, false),
    { "one", "two", "three" },
    "chained <A-0> WITHOUT reselecting strips the numbering back off"
  )

  vim.api.nvim_buf_set_lines(ebuf, 0, -1, false, { "one", "two" })
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  vim.api.nvim_feedkeys(vim.keycode("<Esc>Vj<A-c>"), "mtx", false)
  eq_lines(
    vim.api.nvim_buf_get_lines(ebuf, 0, -1, false),
    { "- [ ] one", "- [ ] two" },
    "V + <A-c> adds a checkbox to the whole selection"
  )
  eq(vim.fn.mode(), "V", "selection survives <A-c> checkbox toggle")
  vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "mtx", false)

  -- <leader><Right> (charwise) swaps the selection with its right neighbor
  -- and keeps the *swapped text* selected — the neighbor moves into the
  -- selection's old slot, so the reselect must follow the shifted text, not
  -- the original byte columns (regression test for that shift).
  vim.api.nvim_buf_set_lines(ebuf, 0, -1, false, { "abcde" })
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  vim.api.nvim_feedkeys(vim.keycode("<Esc>vl <Right>"), "mtx", false)
  eq_lines(vim.api.nvim_buf_get_lines(ebuf, 0, -1, false), { "cabde" }, "v + <leader><Right> swaps selection right")
  eq(vim.fn.mode(), "v", "selection survives <leader><Right> swap")
  eq(vim.fn.col("v"), 2, "selection follows the swapped text (start)")
  eq(vim.fn.col("."), 3, "selection follows the swapped text (end)")

  -- chained <leader><Right> WITHOUT reselecting: swaps the now-shifted
  -- selection ("ab", at its new position) with its *new* right neighbor.
  vim.api.nvim_feedkeys(vim.keycode(" <Right>"), "mtx", false)
  eq_lines(
    vim.api.nvim_buf_get_lines(ebuf, 0, -1, false),
    { "cdabe" },
    "chained <leader><Right> swaps the shifted selection again"
  )
  eq(vim.fn.mode(), "v", "selection survives chained <leader><Right> swap")
  vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "mtx", false)

  cfg.setup({})

  -- :Cascade renumber — no range = current list block at the cursor.
  vim.api.nvim_buf_set_lines(ebuf, 0, -1, false, { "1. a", "3. b", "5. c" })
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  vim.cmd("Cascade renumber")
  eq_lines(
    vim.api.nvim_buf_get_lines(ebuf, 0, -1, false),
    { "1. a", "2. b", "3. c" },
    ":Cascade renumber fixes the block at the cursor"
  )

  -- :Cascade renumber with an explicit range renumbers just that range.
  vim.api.nvim_buf_set_lines(ebuf, 0, -1, false, { "1. a", "5. b", "9. c" })
  vim.cmd("2,3Cascade renumber")
  eq_lines(
    vim.api.nvim_buf_get_lines(ebuf, 0, -1, false),
    { "1. a", "5. b", "6. c" },
    ":Cascade renumber respects an explicit range"
  )

  -- :Cascade renumber all — every list block in the buffer, independently.
  vim.api.nvim_buf_set_lines(ebuf, 0, -1, false, { "1. a", "3. b", "", "1. x", "9. y" })
  vim.cmd("Cascade renumber all")
  eq_lines(
    vim.api.nvim_buf_get_lines(ebuf, 0, -1, false),
    { "1. a", "2. b", "", "1. x", "2. y" },
    ":Cascade renumber all sweeps every block in the buffer"
  )
end

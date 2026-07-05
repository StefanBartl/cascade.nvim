-- docs/TESTS/commands_spec.lua — user commands exist and feature toggles gate.
---@diagnostic disable: missing-fields, need-check-nil, param-type-mismatch

return function(H)
  local eq = H.eq
  local cfg = require("cascade.config")
  local cascade = require("cascade")

  -- user commands exist after setup
  cascade.setup({})
  eq(vim.fn.exists(":CascadeRotate"), 2, ":CascadeRotate defined")
  eq(vim.fn.exists(":CascadeSort"), 2, ":CascadeSort defined")
  eq(vim.fn.exists(":CascadeReverse"), 2, ":CascadeReverse defined")
  eq(vim.fn.exists(":CascadeStrip"), 2, ":CascadeStrip defined")
  eq(vim.fn.exists(":CascadeIndent"), 2, ":CascadeIndent defined")
  eq(vim.fn.exists(":CascadeDedent"), 2, ":CascadeDedent defined")

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
  cfg.setup({})
end

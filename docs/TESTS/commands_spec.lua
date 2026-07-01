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
end

-- docs/TESTS/cycle_spec.lua — word/boolean cycle.
---@diagnostic disable: missing-fields, need-check-nil, param-type-mismatch

return function(H)
  local eq = H.eq
  local cfg = require("cascade.config")
  cfg.setup({})

  local buf = H.scratch("lua")
  local copts = cfg.get("cycle")

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "local x = true" })
  vim.api.nvim_win_set_cursor(0, { 1, 11 }) -- on "true"
  local ok = require("cascade.cycle.word_cycle").cycle(require("cascade.core.context").new(), copts, 1)
  eq(ok, true, "word cycle handled")
  eq(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1], "local x = false", "true->false")

  cfg.setup({})
end

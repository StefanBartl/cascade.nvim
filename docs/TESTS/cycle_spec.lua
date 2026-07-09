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

  -- Facade-level: +/-, and <C-y>/<C-x>, on a writable buffer. Dot-repeatable
  -- actions go through g@l via feedkeys(mode "n"), which is queued rather
  -- than synchronous — flush the typeahead after each call.
  cfg.setup({})
  local cascade = require("cascade")
  local ebuf = H.editable("text")
  local function flush()
    vim.api.nvim_feedkeys("", "x", false)
  end

  -- +/- cycle a word exactly like <C-y>/<C-x>.
  vim.api.nvim_buf_set_lines(ebuf, 0, -1, false, { "flag = true" })
  vim.api.nvim_win_set_cursor(0, { 1, 7 })
  cascade.increment()
  flush()
  eq(vim.api.nvim_buf_get_lines(ebuf, 0, 1, false)[1], "flag = false", "+ cycles word forward")
  cascade.decrement()
  flush()
  eq(vim.api.nvim_buf_get_lines(ebuf, 0, 1, false)[1], "flag = true", "- cycles word backward")

  -- On a number, +/- and <C-y>/<C-x> use the real native increment/decrement
  -- (<C-a>/<C-x>), not their own key fed back at itself.
  vim.api.nvim_buf_set_lines(ebuf, 0, -1, false, { "count = 41" })
  vim.api.nvim_win_set_cursor(0, { 1, 8 })
  cascade.increment()
  flush()
  eq(vim.api.nvim_buf_get_lines(ebuf, 0, 1, false)[1], "count = 42", "+ increments a number")

  vim.api.nvim_buf_set_lines(ebuf, 0, -1, false, { "count = 41" })
  vim.api.nvim_win_set_cursor(0, { 1, 8 })
  cascade.cycle_word_next()
  flush()
  eq(vim.api.nvim_buf_get_lines(ebuf, 0, 1, false)[1], "count = 42", "<C-y> increments a number")

  -- Off a cyclable word and a number, +/- fall back to their native
  -- first-non-blank-of-next/prev-line motion instead of doing nothing.
  vim.api.nvim_buf_set_lines(ebuf, 0, -1, false, { "plain text", "second line" })
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  cascade.increment()
  flush()
  eq(vim.api.nvim_win_get_cursor(0)[1], 2, "+ falls back to native line-down motion")

  cfg.setup({})
end

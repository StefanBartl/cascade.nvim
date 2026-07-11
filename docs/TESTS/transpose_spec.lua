-- docs/TESTS/transpose_spec.lua — char/selection swap with left/right
-- neighbor: ASCII, UTF-8 multibyte, and line-boundary no-ops.
---@diagnostic disable: missing-fields, need-check-nil, param-type-mismatch

return function(H)
  local eq = H.eq
  local buf = H.scratch("text")
  local char = require("cascade.transpose.char")
  local Context = require("cascade.core.context")

  -- swap right: "ab" cursor on 'a' -> "ba", cursor follows to 'a' (col 1).
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "ab" })
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  eq(char.char(Context.new(), 1), true, "swap right: handled")
  eq(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1], "ba", "swap right: result")
  eq(vim.api.nvim_win_get_cursor(0)[2], 1, "swap right: cursor follows swapped char")

  -- swap left: "ba" cursor on 'a' (col 1) -> "ab", cursor follows to col 0.
  eq(char.char(Context.new(), -1), true, "swap left: handled")
  eq(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1], "ab", "swap left: result")
  eq(vim.api.nvim_win_get_cursor(0)[2], 0, "swap left: cursor follows swapped char")

  -- boundary no-ops: nothing to the right of the last char, nothing to the
  -- left of the first.
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "ab" })
  vim.api.nvim_win_set_cursor(0, { 1, 1 }) -- on 'b', the last char
  eq(char.char(Context.new(), 1), false, "swap right at line end: no-op")
  vim.api.nvim_win_set_cursor(0, { 1, 0 }) -- on 'a', the first char
  eq(char.char(Context.new(), -1), false, "swap left at line start: no-op")

  -- UTF-8: multibyte chars move as one unit, not byte-by-byte.
  -- "aäb" — cursor on "ä" (byte col 1, 2 bytes wide) swapped right with "b".
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "aäb" })
  vim.api.nvim_win_set_cursor(0, { 1, 1 })
  eq(char.char(Context.new(), 1), true, "utf8 swap right: handled")
  eq(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1], "abä", "utf8 swap right: result")

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "aäb" })
  vim.api.nvim_win_set_cursor(0, { 1, 1 })
  eq(char.char(Context.new(), -1), true, "utf8 swap left: handled")
  eq(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1], "äab", "utf8 swap left: result")

  -- selection: same-line multi-char selection swaps with a single neighbor.
  -- "xyzw" selecting "yz" (byte cols 1-2) right -> "xwyz".
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "xyzw" })
  eq(char.selection(buf, 0, 1, 2, 1), true, "selection right: handled")
  eq(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1], "xwyz", "selection right: result")

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "xyzw" })
  eq(char.selection(buf, 0, 1, 2, -1), true, "selection left: handled")
  eq(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1], "yzxw", "selection left: result")

  -- selection boundary no-ops.
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "xyzw" })
  eq(char.selection(buf, 0, 2, 3, 1), false, "selection right at line end: no-op")
  eq(char.selection(buf, 0, 0, 1, -1), false, "selection left at line start: no-op")

  -- selection across a missing/invalid line is a safe no-op.
  eq(char.selection(buf, 99, 0, 0, 1), false, "selection on missing line: no-op")
end

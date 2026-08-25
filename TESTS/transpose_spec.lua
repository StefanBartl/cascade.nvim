-- TESTS/transpose_spec.lua — char/word/selection swap with left/right
-- neighbor: ASCII, UTF-8 multibyte, and line-boundary no-ops.
---@diagnostic disable: missing-fields, need-check-nil, param-type-mismatch

return function(H)
  local eq = H.eq
  local buf = H.scratch("text")
  local char = require("cascade.transpose.char")
  local word = require("cascade.transpose.word")
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
  -- "xyzw" selecting "yz" (byte cols 1-2) right -> "xwyz". The swapped-in
  -- neighbor "w" moves into the selection's old slot, so the selected text
  -- "yz" itself shifts right by one byte (col 2-3) — callers reselecting
  -- the *new* bounds (not the original 1-2) keep the same text selected.
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "xyzw" })
  local ok, new_scol, new_ecol = char.selection(buf, 0, 1, 2, 1)
  eq(ok, true, "selection right: handled")
  eq(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1], "xwyz", "selection right: result")
  eq(new_scol, 2, "selection right: new_scol follows the shifted text")
  eq(new_ecol, 3, "selection right: new_ecol follows the shifted text")

  -- Swapping left shifts the selected text left by the neighbor's width:
  -- "xyzw" selecting "yz" (cols 1-2) left -> "yzxw", "yz" now at cols 0-1.
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "xyzw" })
  local ok2, new_scol2, new_ecol2 = char.selection(buf, 0, 1, 2, -1)
  eq(ok2, true, "selection left: handled")
  eq(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1], "yzxw", "selection left: result")
  eq(new_scol2, 0, "selection left: new_scol follows the shifted text")
  eq(new_ecol2, 1, "selection left: new_ecol follows the shifted text")

  -- selection boundary no-ops.
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "xyzw" })
  eq(char.selection(buf, 0, 2, 3, 1), false, "selection right at line end: no-op")
  eq(char.selection(buf, 0, 0, 1, -1), false, "selection left at line start: no-op")

  -- selection across a missing/invalid line is a safe no-op.
  eq(char.selection(buf, 99, 0, 0, 1), false, "selection on missing line: no-op")

  -- word swap right: "foo bar" cursor on "foo" -> "bar foo", cursor follows
  -- the moved word (col 4, the "f" of the relocated "foo").
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "foo bar" })
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  eq(word.word(Context.new(), 1), true, "word swap right: handled")
  eq(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1], "bar foo", "word swap right: result")
  eq(vim.api.nvim_win_get_cursor(0)[2], 4, "word swap right: cursor follows moved word")

  -- word swap left: "foo bar" cursor on "bar" -> "bar foo", cursor follows
  -- the moved word back to col 0.
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "foo bar" })
  vim.api.nvim_win_set_cursor(0, { 1, 4 })
  eq(word.word(Context.new(), -1), true, "word swap left: handled")
  eq(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1], "bar foo", "word swap left: result")
  eq(vim.api.nvim_win_get_cursor(0)[2], 0, "word swap left: cursor follows moved word")

  -- the separator between the two words moves as a block, unchanged: a
  -- non-space separator (comma, no space) stays a comma, not a space.
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "foo,bar" })
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  eq(word.word(Context.new(), 1), true, "word swap right (comma gap): handled")
  eq(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1], "bar,foo", "word swap right (comma gap): result")

  -- word boundary no-ops: nothing to the right of the last word, nothing to
  -- the left of the first.
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "foo bar" })
  vim.api.nvim_win_set_cursor(0, { 1, 4 }) -- on "bar", the last word
  eq(word.word(Context.new(), 1), false, "word swap right at line end: no-op")
  vim.api.nvim_win_set_cursor(0, { 1, 0 }) -- on "foo", the first word
  eq(word.word(Context.new(), -1), false, "word swap left at line start: no-op")

  -- cursor not on a word (e.g. sitting on the separator) is a safe no-op.
  vim.api.nvim_win_set_cursor(0, { 1, 3 }) -- the space in "foo bar"
  eq(word.word(Context.new(), 1), false, "word swap on non-word cursor: no-op")

  -- UTF-8: a multibyte word character ("é") stays inside its word, moving
  -- as part of the whole token, not torn apart.
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "café bar" })
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  eq(word.word(Context.new(), 1), true, "utf8 word swap right: handled")
  eq(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1], "bar café", "utf8 word swap right: result")

  -- word selection swap: same-line selection swaps with a whole neighbor
  -- word (not just a single character, unlike char.selection). "ab cd ef"
  -- selecting "cd" (byte cols 3-4) right -> "ab ef cd".
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "ab cd ef" })
  local wok, wns, wne = word.word_selection(buf, 0, 3, 4, 1)
  eq(wok, true, "word selection right: handled")
  eq(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1], "ab ef cd", "word selection right: result")
  eq(wns, 6, "word selection right: new_scol follows the shifted text")
  eq(wne, 7, "word selection right: new_ecol follows the shifted text")

  -- same selection swapped left -> "cd ab ef".
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "ab cd ef" })
  local wok2, wns2, wne2 = word.word_selection(buf, 0, 3, 4, -1)
  eq(wok2, true, "word selection left: handled")
  eq(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1], "cd ab ef", "word selection left: result")
  eq(wns2, 0, "word selection left: new_scol follows the shifted text")
  eq(wne2, 1, "word selection left: new_ecol follows the shifted text")

  -- word selection boundary no-ops.
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "ab cd ef" })
  eq(word.word_selection(buf, 0, 6, 7, 1), false, "word selection right at line end: no-op")
  eq(word.word_selection(buf, 0, 0, 1, -1), false, "word selection left at line start: no-op")

  -- word selection across a missing/invalid line is a safe no-op.
  eq(word.word_selection(buf, 99, 0, 0, 1), false, "word selection on missing line: no-op")
end

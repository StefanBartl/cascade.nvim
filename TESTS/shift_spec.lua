-- TESTS/shift_spec.lua — ordered-list stepping: `<C-y>`/`<C-x>` on a marker shift
-- the item and its LATER siblings (no renumber), `shift_level_*` the whole level.
---@diagnostic disable: missing-fields, need-check-nil, param-type-mismatch

return function(H)
  local eq_lines = H.eq_lines
  local cfg = require("cascade.config")
  cfg.setup({})
  local lopts = cfg.get("lists")
  local cascade = require("cascade")
  cascade.setup({})
  local shift = require("cascade.lists.shift")

  local buf = H.editable("markdown")
  local function set(lines, row, col)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_win_set_cursor(0, { row, col or 0 })
  end
  local function get()
    return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  end

  -- ── pure: shift.shift ────────────────────────────────────────────────────
  -- "following": the cursor item and the siblings after it; the ones before stay.
  set({ "1. one", "2. two", "3. three" }, 2)
  H.eq(shift.shift(buf, 1, -1, "following", lopts), true, "shift returns true when it changed lines")
  eq_lines(get(), { "1. one", "1. two", "2. three" }, "following, -1 from the middle item")

  set({ "1. one", "2. two", "3. three" }, 3)
  shift.shift(buf, 2, -1, "following", lopts)
  eq_lines(get(), { "1. one", "2. two", "2. three" }, "following on the last item moves only it")

  set({ "1. one", "2. two", "3. three" }, 1)
  shift.shift(buf, 0, 2, "following", lopts)
  eq_lines(get(), { "3. one", "4. two", "5. three" }, "following on the first item = whole list, +2")

  -- "level": before AND after.
  set({ "1. one", "2. two", "3. three" }, 2)
  shift.shift(buf, 1, 5, "level", lopts)
  eq_lines(get(), { "6. one", "7. two", "8. three" }, "level shifts every sibling")

  -- A list that starts elsewhere keeps its room: no renumber to 1..n.
  set({ "5. a", "9. b", "12. c" }, 2)
  shift.shift(buf, 1, -1, "following", lopts)
  eq_lines(get(), { "5. a", "8. b", "11. c" }, "gaps and start offset survive")

  -- Deeper children and continuation lines are not touched; the level continues past them.
  set({ "1. one", "   - child", "   2. nested", "2. two", "   wrapped text", "3. three" }, 1)
  shift.shift(buf, 0, 1, "following", lopts)
  eq_lines(
    get(),
    { "2. one", "   - child", "   2. nested", "3. two", "   wrapped text", "4. three" },
    "children and continuation untouched, siblings past them follow"
  )

  -- Nested level on its own.
  set({ "1. one", "   1. a", "   2. b", "2. two" }, 2)
  shift.shift(buf, 1, 3, "level", lopts)
  eq_lines(get(), { "1. one", "   4. a", "   5. b", "2. two" }, "a nested level shifts alone")

  -- A blank line ends the block.
  set({ "1. a", "2. b", "", "1. c" }, 1)
  shift.shift(buf, 0, 1, "level", lopts)
  eq_lines(get(), { "2. a", "3. b", "", "1. c" }, "a blank line ends the run")

  -- Letters and Roman numerals move through their own sequence, case kept.
  set({ "a) x", "b) y", "c) z" }, 2)
  shift.shift(buf, 1, 1, "following", lopts)
  eq_lines(get(), { "a) x", "c) y", "d) z" }, "letters step through the alphabet")
  set({ "I. x", "II. y", "III. z" }, 1)
  shift.shift(buf, 0, 1, "level", lopts)
  eq_lines(get(), { "II. x", "III. y", "IV. z" }, "Roman numerals step, case kept")

  -- Out of range: nothing changes at all, and it says why.
  set({ "a) x", "b) y" }, 1)
  local changed, err = shift.shift(buf, 0, -1, "level", lopts)
  H.eq(changed, false, "below `a`: refused")
  H.ok(err and err:find("out of range", 1, true), "…with a reason")
  eq_lines(get(), { "a) x", "b) y" }, "…and the buffer is untouched")
  set({ "1. x", "2. y" }, 1)
  H.eq((shift.shift(buf, 0, -2, "level", lopts)), false, "digits stop at 0: 1 - 2 is refused")
  eq_lines(get(), { "1. x", "2. y" }, "…nothing moved")
  set({ "1. x", "2. y" }, 1)
  shift.shift(buf, 0, -1, "level", lopts)
  eq_lines(get(), { "0. x", "1. y" }, "digits may go down to 0")

  -- Not an ordered item.
  set({ "- bullet", "plain" }, 1)
  H.eq(shift.shift(buf, 0, 1, "level", lopts), nil, "a bullet is not an ordered item (nil)")
  H.eq(shift.shift(buf, 1, 1, "level", lopts), nil, "plain text is not an item (nil)")

  -- ── on_marker: only where a native <C-a> would hit the marker's number ───
  H.eq(shift.on_marker("  2. Testing 3 apples", 0, lopts), true, "cursor in the indent")
  H.eq(shift.on_marker("  2. Testing 3 apples", 2, lopts), true, "cursor on the number")
  H.eq(shift.on_marker("  2. Testing 3 apples", 4, lopts), true, "cursor on the space after the marker")
  H.eq(shift.on_marker("  2. Testing 3 apples", 14, lopts), false, "cursor in the text: native stepping of `3`")
  H.eq(shift.on_marker("- bullet", 0, lopts), false, "a bullet has no number")

  -- Dot-repeatable actions run through g@l, which feedkeys queues -- flush it.
  local function flush()
    vim.api.nvim_feedkeys("", "x", false)
  end

  -- ── through the stepping keys' API (cascade.increment == <C-y>/+ family) ─
  set({ "1. Test", "  2. Testing", "  3. Testung" }, 2, 2)
  cascade.cycle_word_prev()
  flush()
  eq_lines(get(), { "1. Test", "  1. Testing", "  2. Testung" }, "<C-x> on `2.`: the item and the later sibling follow")

  set({ "1. Test", "  2. Testing", "  3. Testung" }, 3, 2)
  cascade.cycle_word_next()
  flush()
  eq_lines(get(), { "1. Test", "  2. Testing", "  4. Testung" }, "<C-y> on `3.`: only it moves (nothing after it)")

  -- Cursor in the text keeps the native/number behaviour (the `3` is stepped, not the marker).
  set({ "2. Buy 3 apples" }, 1, 7)
  cascade.increment()
  flush()
  eq_lines(get(), { "2. Buy 4 apples" }, "cursor on a number in the text: that number, not the marker")

  -- Level variant: whole level, wherever the cursor is on the item.
  set({ "1. a", "2. b", "3. c" }, 3, 6)
  cascade.shift_level_next()
  flush()
  eq_lines(get(), { "2. a", "3. b", "4. c" }, "shift_level_next: every sibling +1, cursor anywhere on the item")
  cascade.shift_level_prev()
  flush()
  cascade.shift_level_prev()
  eq_lines(get(), { "0. a", "1. b", "2. c" }, "shift_level_prev twice: -2 for the whole level")

  -- Feature switch.
  cfg.setup({ lists = { features = { shift = false } } })
  set({ "1. a", "2. b", "3. c" }, 2, 0)
  cascade.cycle_word_prev()
  flush()
  H.ok(table.concat(get(), "|") ~= "1. a|1. b|2. c", "lists.features.shift = false: no list shifting")
  cfg.setup({})
end

-- docs/TESTS/lists_spec.lua — buffer-level list operations:
-- continuation/checkbox, renumber (run/tree/all), transforms, indent, move.
---@diagnostic disable: missing-fields, need-check-nil, param-type-mismatch, assign-type-mismatch

return function(H)
  local eq = H.eq
  local eq_lines = H.eq_lines
  local cfg = require("cascade.config")
  cfg.setup({})
  local lopts = cfg.get("lists")

  local buf = H.scratch("markdown")
  local cascade = require("cascade")
  cascade.setup({})

  -- checkbox toggle promotes an ordered item to a checkbox item
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "1. one", "2. two" })
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  require("cascade.lists.checkbox").toggle(require("cascade.core.context").new(), lopts)
  eq(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1], "1. [ ] one", "checkbox promote")

  -- renumber.run after a manual insert
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "1. a", "1. b", "1. c" })
  require("cascade.lists.renumber").run(buf, 1, lopts)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  eq(lines[2], "2. b", "renumber l2")
  eq(lines[3], "3. c", "renumber l3")

  -- form rotation: 1. -> 1. [ ] -> - [ ] -> -
  local transform = require("cascade.lists.transform")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "1. one", "2. two", "3. three" })
  local s_, e_ = transform.block_range(buf, 0, lopts)
  eq(s_, 0, "block start")
  eq(e_, 2, "block end")
  transform.rotate(buf, s_, e_, 1, lopts)
  eq(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1], "1. [ ] one", "rotate to numbered checkbox")
  eq(vim.api.nvim_buf_get_lines(buf, 1, 2, false)[1], "2. [ ] two", "rotate l2")
  transform.rotate(buf, s_, e_, 1, lopts)
  eq(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1], "- [ ] one", "rotate to task list")
  transform.rotate(buf, s_, e_, 1, lopts)
  eq(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1], "- one", "rotate to plain bullet")

  -- checkbox state survives rotation
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "- [x] done", "- [ ] todo" })
  transform.rotate(buf, 0, 1, 1, lopts)
  eq(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1], "- done", "task -> plain keeps no checkbox")

  -- sort A-Z with renumber
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "1. banana", "2. apple", "3. cherry" })
  transform.sort(buf, 0, 2, 1, lopts)
  local sl = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  eq(sl[1], "1. apple", "sort 1")
  eq(sl[2], "2. banana", "sort 2")
  eq(sl[3], "3. cherry", "sort 3")

  -- reverse order (renumbered)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "1. a", "2. b", "3. c" })
  transform.reverse(buf, 0, 2, 1, lopts)
  local rv = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  eq(rv[1], "1. c", "reverse 1")
  eq(rv[2], "2. b", "reverse 2")
  eq(rv[3], "3. a", "reverse 3")

  -- strip checkboxes (markers kept)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "1. [x] a", "2. [ ] b" })
  transform.strip(buf, 0, 1, 1, lopts)
  local st = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  eq(st[1], "1. a", "strip 1")
  eq(st[2], "2. b", "strip 2")

  -- indent-aware tree renumber — the three user scenarios.
  local rn = require("cascade.lists.renumber")

  -- (a) deeper item starts a new "1." run; the level it left closes its gap.
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    "1. top",
    "  1. a",
    "  2. b",
    "    3. c",
    "  4. d",
    "  5. e",
    "2. bot",
  })
  rn.tree(buf, 0, 6, lopts)
  local t1 = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  eq(t1[4], "    1. c", "deeper item resets to 1")
  eq(t1[5], "  3. d", "left level closes gap (4->3)")
  eq(t1[6], "  4. e", "left level closes gap (5->4)")
  eq(t1[7], "2. bot", "base level continues")

  -- (b) an outdented item joins the parent level; items after shift down.
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    "1. top",
    "  1. a",
    "  2. b",
    "  3. c",
    "4. d",
    "  5. e",
    "2. bot",
  })
  rn.tree(buf, 0, 6, lopts)
  local t2 = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  eq(t2[5], "2. d", "outdented item becomes 2. at parent level")
  eq(t2[7], "3. bot", "old parent 2. becomes 3.")

  -- (c) a top-level item indented under a nested run appends to it.
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    "1. top",
    "  1. a",
    "  2. b",
    "  3. c",
    "  4. d",
    "  5. e",
    "  2. bot",
  })
  rn.tree(buf, 0, 6, lopts)
  local t3 = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  eq(t3[7], "  6. bot", "indented item appends as 6.")

  -- (d) indent.shift_line integration: shift a single list line + renumber.
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "1. a", "2. b", "3. c" })
  vim.bo[buf].expandtab = true
  vim.bo[buf].shiftwidth = 2
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  require("cascade.lists.indent").shift_line(require("cascade.core.context").new(), lopts, 1, 1)
  local si = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  eq(si[2], "  1. b", "shifted line deeper -> new run 1.")
  eq(si[3], "2. c", "old level closes gap (3->2)")

  -- move line down re-sequences the ordered list.
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "1. a", "2. b", "3. c" })
  vim.bo[buf].filetype = "markdown"
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  require("cascade.lists.move").line(buf, 1, lopts)
  local mv = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  eq(mv[1], "1. a", "move: l1")
  eq(mv[2], "2. c", "move: text reordered + renumbered")
  eq(mv[3], "3. b", "move: b now last, renumbered")

  -- move.selection guards the buffer boundary (E16 prevention): moving a
  -- selection that already touches the edge is a no-op, never a Vim error.
  local move = require("cascade.lists.move")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "1. a", "2. b", "3. c" })
  eq(move.selection(buf, 1, 2, 1, lopts), false, "move sel down at last line = no-op")
  eq(move.selection(buf, 0, 0, -1, lopts), false, "move sel up at first line = no-op")

  -- indent.shift_range shifts every line of a range and renumbers the block:
  -- the two indented lines become a fresh sub-run under the untouched parent.
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "1. a", "2. b", "3. c" })
  vim.bo[buf].expandtab = true
  vim.bo[buf].shiftwidth = 2
  require("cascade.lists.indent").shift_range(buf, 1, 2, 1, 1, lopts, true)
  local sr = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  eq(sr[1], "1. a", "shift_range: parent untouched")
  eq(sr[2], "  1. b", "shift_range: first shifted line resets to 1")
  eq(sr[3], "  2. c", "shift_range: second shifted line continues")

  -- renumber trigger config: "edit" vs "save", boolean back-compat.
  cfg.setup({})
  eq(rn.at(cfg.get("lists"), "edit"), true, "default renumbers on edit")
  eq(rn.at(cfg.get("lists"), "save"), false, "default does not renumber on save")
  cfg.setup({ lists = { renumber = { on = { "save" } } } })
  eq(rn.at(cfg.get("lists"), "edit"), false, "save-only: not on edit")
  eq(rn.at(cfg.get("lists"), "save"), true, "save-only: on save")
  cfg.setup({ lists = { renumber = true } })
  eq(rn.at(cfg.get("lists"), "edit"), true, "boolean true normalizes to edit")
  cfg.setup({ lists = { renumber = false } })
  eq(rn.at(cfg.get("lists"), "edit"), false, "boolean false disables")

  -- renumber.all over a multi-block buffer: a single blank line is tolerated
  -- inside a block (a "loose" list stays one block); a run of two or more
  -- ends it and starts a fresh block with its own start offset.
  cfg.setup({})
  local lo = cfg.get("lists")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "1. a", "1. b", "", "5. x", "9. y" })
  rn.all(buf, lo)
  local all = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  eq(all[2], "2. b", "all: block 1 renumbered")
  eq(all[4], "3. x", "all: a single blank line doesn't break the sequence")
  eq(all[5], "4. y", "all: sequence keeps carrying on")

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "1. a", "1. b", "", "", "5. x", "9. y" })
  rn.all(buf, lo)
  local twoblank = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  eq(twoblank[2], "2. b", "all: block 1 renumbered")
  eq(twoblank[5], "5. x", "all: two blank lines start a fresh block, own start offset kept")
  eq(twoblank[6], "6. y", "all: fresh block renumbers sequentially")

  -- A non-marker, non-blank line never breaks the sequence, regardless of its
  -- own indent — matches Markdown "lazy continuation": without a blank line
  -- separating it from the item above, it belongs to that item.
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    "  1. one",
    "    a wrapped continuation paragraph",
    "  1. two",
    "  2. three",
  })
  rn.all(buf, lo)
  local cont = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  eq(cont[3], "  2. two", "continuation: sequence carries on past deeper text")
  eq(cont[4], "  3. three", "continuation: sequence carries on past deeper text")

  -- ...even a flush (unindented) paragraph, since there's no blank line.
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    "1. a",
    "1. b",
    "A flush, unindented note right below — no blank line.",
    "5. x",
    "9. y",
  })
  rn.all(buf, lo)
  local flush = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  eq(flush[2], "2. b", "flush continuation: block 1 renumbered")
  eq(flush[4], "3. x", "flush continuation: no blank line means no break, even unindented")
  eq(flush[5], "4. y", "flush continuation: sequence keeps carrying on")

  -- The reported real-world case: flush notes directly under each item, with
  -- repeated "1." source markers and no blank lines anywhere.
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    "1. item A",
    "*note A*",
    "1. item B",
    "*note B*",
    "1. item C",
    "2. item D",
  })
  rn.all(buf, lo)
  local repeated = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  eq(repeated[3], "2. item B", "repeated-1.: flush note doesn't reset the sequence")
  eq(repeated[5], "3. item C", "repeated-1.: sequence carries through both notes")
  eq(repeated[6], "4. item D", "repeated-1.: sequence carries through both notes")

  -- transform.block_range must span a continuation paragraph the same way,
  -- so the interactive indent-on-edit path (indent.lua -> block_range ->
  -- renumber.tree) renumbers immediately, without needing a save first.
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    "1. Product Module: ...",
    "  Note on Module Export: ...",
    "1. Tosca Version: ...",
    "2. Repository Type: ...",
    "3. Visuals: ...",
    "4. System Logs: ...",
  })
  vim.bo[buf].expandtab = true
  vim.bo[buf].shiftwidth = 2
  vim.api.nvim_win_set_cursor(0, { 4, 0 }) -- "2. Repository Type"
  require("cascade.lists.indent").shift_line(require("cascade.core.context").new(), lo, 1, 1)
  local ind = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  eq(ind[3], "2. Tosca Version: ...", "indent-on-edit: renumbers across a continuation paragraph immediately")
  eq(ind[4], "  1. Repository Type: ...", "indent-on-edit: shifted line nests to 1.")
  eq(ind[5], "3. Visuals: ...", "indent-on-edit: base-level gap closed (3->3, unaffected)")
  eq(ind[6], "4. System Logs: ...", "indent-on-edit: base-level gap closed (4->4, unaffected)")

  -- quick_toggle: bullet/number/checkbox work without an existing marker,
  -- unlike checkbox.toggle/cycle_type.cycle which no-op without one.
  cfg.setup({})
  local qt = require("cascade.lists.quick_toggle")
  local Context = require("cascade.core.context")

  -- bullet: plain line -> "-" bullet -> plain line again.
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "Hello world" })
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  eq(qt.bullet(Context.new(), lo), true, "bullet: inserts")
  eq(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1], "- Hello world", "bullet: inserted")
  eq(qt.bullet(Context.new(), lo), true, "bullet: strips")
  eq(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1], "Hello world", "bullet: stripped back to plain text")

  -- bullet: converts a different marker kind instead of stacking a new one,
  -- preserving its checkbox (matches cycle_type.cycle's behavior).
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "1. [x] Hello" })
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  qt.bullet(Context.new(), lo)
  eq(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1], "- [x] Hello", "bullet: converts digit marker, keeps its checkbox")

  -- number: plain line -> "1." -> renumbers against a sibling -> plain line.
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "1. First", "Second" })
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  eq(qt.number(Context.new(), lo), true, "number: inserts")
  local nl = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  eq(nl[2], "2. Second", "number: inserted + renumbered against sibling")
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  eq(qt.number(Context.new(), lo), true, "number: strips")
  eq(vim.api.nvim_buf_get_lines(buf, 1, 2, false)[1], "Second", "number: stripped back to plain text")

  -- checkbox: full none -> "[ ]" -> "[x]" -> none cycle on a plain line.
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "Task item" })
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  qt.checkbox(Context.new(), lo)
  eq(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1], "- [ ] Task item", "checkbox: created from plain line")
  qt.checkbox(Context.new(), lo)
  eq(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1], "- [x] Task item", "checkbox: advances to next state")
  qt.checkbox(Context.new(), lo)
  eq(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1], "Task item", "checkbox: last state strips the whole item")

  -- checkbox: promotes an existing marker instead of creating a new bullet.
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "1. Buy milk" })
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  qt.checkbox(Context.new(), lo)
  eq(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1], "1. [ ] Buy milk", "checkbox: promotes existing digit marker")

  -- star: same on/off toggle as bullet, using "*" instead of "-".
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "Hello world" })
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  eq(qt.star(Context.new(), lo), true, "star: inserts")
  eq(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1], "* Hello world", "star: inserted")
  eq(qt.star(Context.new(), lo), true, "star: strips")
  eq(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1], "Hello world", "star: stripped back to plain text")

  -- quick_toggle _range: applied independently to every non-blank line in a
  -- range, same as the Visual-mode <A-->/<A-*>/<A-0>/<A-c> bindings. Blank
  -- lines and, for number, an already-mixed marker are handled per line.
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "one", "two", "three" })
  qt.bullet_range(buf, 0, 2, 1, lo)
  eq_lines(vim.api.nvim_buf_get_lines(buf, 0, -1, false), { "- one", "- two", "- three" }, "bullet_range: every line toggled on")
  qt.bullet_range(buf, 0, 2, 1, lo)
  eq_lines(vim.api.nvim_buf_get_lines(buf, 0, -1, false), { "one", "two", "three" }, "bullet_range: every line toggled off")

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "one", "two", "three" })
  qt.star_range(buf, 0, 2, 1, lo)
  eq_lines(vim.api.nvim_buf_get_lines(buf, 0, -1, false), { "* one", "* two", "* three" }, "star_range: every line toggled on")

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "one", "- two", "three" })
  qt.number_range(buf, 0, 2, 1, lo)
  eq_lines(
    vim.api.nvim_buf_get_lines(buf, 0, -1, false),
    { "1. one", "2. two", "3. three" },
    "number_range: converts an existing different marker too, renumbered sequentially"
  )

  -- number_range always leaves a correctly sequential result, even when the
  -- renumber-on-edit trigger is off (regression: it used to rely on that
  -- trigger firing per line as a side effect, so every line landed on "1."
  -- instead of 1/2/3 when the trigger was disabled).
  cfg.setup({ lists = { renumber = { on = { "save" } } } })
  local lo_no_edit = cfg.get("lists")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "one", "two", "three" })
  qt.number_range(buf, 0, 2, 1, lo_no_edit)
  eq_lines(
    vim.api.nvim_buf_get_lines(buf, 0, -1, false),
    { "1. one", "2. two", "3. three" },
    "number_range: sequential even with the edit-trigger renumber disabled"
  )
  cfg.setup({})
  lo = cfg.get("lists")

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "one", "two" })
  qt.checkbox_range(buf, 0, 1, 1, lo)
  eq_lines(
    vim.api.nvim_buf_get_lines(buf, 0, -1, false),
    { "- [ ] one", "- [ ] two" },
    "checkbox_range: every line gets a checkbox"
  )

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "one", "", "three" })
  qt.bullet_range(buf, 0, 2, 1, lo)
  eq_lines(
    vim.api.nvim_buf_get_lines(buf, 0, -1, false),
    { "- one", "", "- three" },
    "bullet_range: blank line inside is skipped"
  )

  cfg.setup({})
end

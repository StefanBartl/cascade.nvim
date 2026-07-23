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

  -- (c2) preserve_start = false (default): a nested level always resets to 1
  -- on its first occurrence, even if it already carries a higher number —
  -- the right call right after indenting a single item deeper.
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    "1. top",
    "  2. a",
    "    5. b",
    "    6. c",
    "  3. d",
  })
  rn.tree(buf, 0, 4, lopts)
  local t4 = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  eq(t4[3], "    1. b", "default: nested run resets to 1")
  eq(t4[4], "    2. c", "default: nested run continues from 1")

  -- (c3) preserve_start = true: the same nested run instead keeps its own
  -- deliberately-authored start offset — used when renumbering already
  -- existing text (M.all on save, the explicit :Cascade renumber command).
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    "1. top",
    "  2. a",
    "    5. b",
    "    6. c",
    "  3. d",
  })
  rn.tree(buf, 0, 4, lopts, true)
  local t5 = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  eq(t5[3], "    5. b", "preserve_start: nested run keeps its own start offset")
  eq(t5[4], "    6. c", "preserve_start: nested run continues from 5")

  -- M.all (save sweep) preserves a nested list's own start offset too.
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    "1. top",
    "  5. x",
    "  6. y",
    "  7. z",
    "2. bot",
  })
  rn.all(buf, lopts)
  local t6 = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  eq(t6[2], "  5. x", "all: nested list keeps its own start offset")
  eq(t6[3], "  6. y", "all: nested list continues from 5")
  eq(t6[4], "  7. z", "all: nested list continues from 5")
  eq(t6[5], "2. bot", "all: base level unaffected")

  -- (d) indent.shift_line integration: shift a single list line + renumber.
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "1. a", "2. b", "3. c" })
  vim.bo[buf].expandtab = true
  vim.bo[buf].shiftwidth = 2
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  require("cascade.lists.indent").shift_line(require("cascade.core.context").new(), lopts, 1, 1)
  local si = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  eq(si[2], "  1. b", "shifted line deeper -> new run 1.")
  eq(si[3], "2. c", "old level closes gap (3->2)")

  -- (e) subtree-aware indent: indenting an item carries its deeper-indented
  -- children (grandchildren here) along; a sibling at the item's old level
  -- is untouched by the shift and closes the numbering gap it left behind.
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    "1. top",
    "  1. item",
    "    1. grandchild x",
    "    2. grandchild y",
    "  2. sibling",
    "2. bot",
  })
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  require("cascade.lists.indent").shift_line(require("cascade.core.context").new(), lopts, 1, 1)
  local sub = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  eq(sub[1], "1. top", "subtree: top untouched")
  eq(sub[2], "    1. item", "subtree: shifted item now two levels deep")
  eq(sub[3], "      1. grandchild x", "subtree: grandchild carried along with its parent")
  eq(sub[4], "      2. grandchild y", "subtree: second grandchild carried along too")
  eq(sub[5], "  1. sibling", "subtree: sibling untouched by the shift, closes the gap it left")
  eq(sub[6], "2. bot", "subtree: base level unaffected")

  -- dedent is the inverse: the subtree follows back out too.
  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  require("cascade.lists.indent").shift_line(require("cascade.core.context").new(), lopts, 1, -1)
  local unsub = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  eq(unsub[2], "  1. item", "subtree dedent: item back at its original depth")
  eq(unsub[3], "    1. grandchild x", "subtree dedent: grandchild follows back out")
  eq(unsub[4], "    2. grandchild y", "subtree dedent: second grandchild follows back out")
  eq(unsub[5], "  2. sibling", "subtree dedent: sibling renumbers back to 2, round trip complete")

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
  eq(rn.at(cfg.get("lists"), "save"), true, "default also renumbers on save")
  cfg.setup({ lists = { renumber = { on = { "save" } } } })
  eq(rn.at(cfg.get("lists"), "edit"), false, "save-only: not on edit")
  eq(rn.at(cfg.get("lists"), "save"), true, "save-only: on save")
  cfg.setup({ lists = { renumber = true } })
  eq(rn.at(cfg.get("lists"), "edit"), true, "boolean true normalizes to edit+save")
  eq(rn.at(cfg.get("lists"), "save"), true, "boolean true normalizes to edit+save")
  cfg.setup({ lists = { renumber = false } })
  eq(rn.at(cfg.get("lists"), "edit"), false, "boolean false disables")

  -- blank_break default (0): any blank line ends a block, so two visually
  -- separate lists are each numbered on their own — the fresh block keeps its
  -- own start offset instead of running on from the block above.
  cfg.setup({})
  local lo = cfg.get("lists")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "1. a", "1. b", "", "5. x", "9. y" })
  rn.all(buf, lo)
  local brk = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  eq(brk[2], "2. b", "all: block 1 renumbered")
  eq(brk[4], "5. x", "all: a blank line breaks the block, fresh start offset kept")
  eq(brk[5], "6. y", "all: fresh block renumbers sequentially")

  -- blank_break = 1: opt into the CommonMark "loose list" reading, where a
  -- single blank line is tolerated inside a block but two or more end it.
  cfg.setup({ lists = { renumber = { blank_break = 1 } } })
  local loose = cfg.get("lists")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "1. a", "1. b", "", "5. x", "9. y" })
  rn.all(buf, loose)
  local all = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  eq(all[2], "2. b", "loose: block 1 renumbered")
  eq(all[4], "3. x", "loose: a single blank line doesn't break the sequence")
  eq(all[5], "4. y", "loose: sequence keeps carrying on")

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "1. a", "1. b", "", "", "5. x", "9. y" })
  rn.all(buf, loose)
  local twoblank = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  eq(twoblank[2], "2. b", "loose: block 1 renumbered")
  eq(twoblank[5], "5. x", "loose: two blank lines start a fresh block, own start offset kept")
  eq(twoblank[6], "6. y", "loose: fresh block renumbers sequentially")
  cfg.setup({})

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

  -- lists.format: 'formatlistpat' derived from the configured marker types,
  -- so native gq/auto-wrap hang-indents a wrapped item under its text.
  local format = require("cascade.lists.format")
  cfg.setup({})
  local fmt_opts = cfg.get("lists") -- default types = { "unordered", "digit" }
  local pat = format.list_pat(fmt_opts)
  eq(vim.fn.match("- one", pat) >= 0, true, "formatlistpat: matches a configured unordered bullet")
  eq(vim.fn.match("1. one", pat) >= 0, true, "formatlistpat: matches a configured digit marker")
  eq(vim.fn.match("i. one", pat) >= 0, false, "formatlistpat: roman not matched when types doesn't include it")
  eq(vim.fn.match("just text", pat) >= 0, false, "formatlistpat: plain text doesn't match")

  cfg.setup({ lists = { types = { "unordered", "digit", "ascii", "roman" } } })
  local fmt_all = cfg.get("lists")
  local pat_all = format.list_pat(fmt_all)
  eq(vim.fn.match("i. one", pat_all) >= 0, true, "formatlistpat: roman matched once configured")
  eq(vim.fn.match("a) one", pat_all) >= 0, true, "formatlistpat: ascii matched once configured")

  -- apply() sets the buffer options; is additive (doesn't strip existing
  -- 'formatoptions' flags) and is a no-op when hanging_indent = false.
  cfg.setup({})
  vim.bo[buf].formatoptions = "tcq"
  format.apply(buf, cfg.get("lists"))
  eq(vim.bo[buf].formatlistpat, format.list_pat(cfg.get("lists")), "format.apply: sets formatlistpat")
  eq(vim.bo[buf].formatoptions:find("n", 1, true) ~= nil, true, "format.apply: adds 'n' to formatoptions")
  eq(vim.bo[buf].formatoptions:find("t", 1, true) ~= nil, true, "format.apply: keeps pre-existing 't' flag")
  eq(vim.bo[buf].formatoptions:find("c", 1, true) ~= nil, true, "format.apply: keeps pre-existing 'c' flag")

  vim.bo[buf].formatlistpat = ""
  cfg.setup({ lists = { continue = { hanging_indent = false } } })
  format.apply(buf, cfg.get("lists"))
  eq(vim.bo[buf].formatlistpat, "", "format.apply: hanging_indent = false is a no-op")

  -- per-filetype custom marker patterns: a filetype-specific pattern (e.g.
  -- LaTeX's \item, which isn't any of the built-in kinds) is recognized only
  -- on its own filetype, always as a fixed, non-incrementing "unordered"-kind
  -- marker.
  cfg.setup({
    lists = {
      per_filetype_patterns = {
        tex = { "^(\\item)%s(.*)$" },
      },
    },
  })
  local marker = require("cascade.lists.marker")
  local pf = cfg.get("lists")

  vim.bo[buf].filetype = "tex"
  local m_tex = marker.parse("\\item Hello world", pf)
  eq(m_tex ~= nil, true, "per_filetype_patterns: \\item recognized on its configured filetype")
  eq(m_tex.kind, "unordered", "per_filetype_patterns: custom marker is kind=unordered")
  eq(m_tex.marker, "\\item", "per_filetype_patterns: marker token captured verbatim")
  eq(m_tex.text, "Hello world", "per_filetype_patterns: text captured after the marker")

  vim.bo[buf].filetype = "markdown"
  eq(marker.parse("\\item Hello world", pf), nil, "per_filetype_patterns: not recognized on a different filetype")

  -- continuation keeps repeating the same fixed token (unordered semantics),
  -- and renumber leaves it alone (it's never treated as ordered).
  vim.bo[buf].filetype = "tex"
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "\\item one" })
  vim.api.nvim_win_set_cursor(0, { 1, #"\\item " }) -- just after the marker, before "one"
  require("cascade.lists.continue").cr(require("cascade.core.context").new(), pf)
  eq_lines(
    vim.api.nvim_buf_get_lines(buf, 0, -1, false),
    { "\\item ", "\\item one" },
    "per_filetype_patterns: <CR> continuation repeats the same fixed token"
  )
  vim.bo[buf].filetype = "markdown"

  -- lists.precision = "treesitter": skip a configured node type (default: a
  -- markdown fenced code block) so a line that only *looks* like a marker
  -- inside a code fence isn't treated as a real list item. The pure/pcall-
  -- safety checks always run; the "actually detects a code fence"
  -- assertions are skipped gracefully if no markdown Treesitter parser is
  -- installed (CI may not have one -- cascade's default line-scan behavior
  -- must never depend on it).
  local treesitter = require("cascade.core.treesitter")

  cfg.setup({})
  eq(treesitter.in_skip_node(buf, 0, 0, "markdown", cfg.get("lists")), false, "precision off (default): never skips")

  cfg.setup({ lists = { precision = "treesitter" } })
  eq(
    treesitter.in_skip_node(buf, 0, 0, "text", cfg.get("lists")),
    false,
    "precision on: no configured skip nodes for this filetype"
  )

  cfg.setup({ lists = { precision = "treesitter", precision_nodes = { text = { "bogus_node_type" } } } })
  local safe_ok = pcall(treesitter.in_skip_node, buf, 0, 0, "text", cfg.get("lists"))
  eq(safe_ok, true, "precision: never errors even against a parser cascade can't find")

  local has_md_parser = pcall(vim.treesitter.get_parser, buf, "markdown")
  if has_md_parser then
    cfg.setup({ lists = { precision = "treesitter" } })
    local pbuf = H.editable("markdown")
    vim.api.nvim_buf_set_lines(pbuf, 0, -1, false, {
      "prose",
      "",
      "```sh",
      "- flag",
      "```",
      "",
      "- outside the fence",
    })
    local popts = cfg.get("lists")
    eq(treesitter.in_skip_node(pbuf, 3, 0, "markdown", popts), true, "precision: detects a line inside a fenced code block")
    eq(treesitter.in_skip_node(pbuf, 6, 0, "markdown", popts), false, "precision: prose outside the fence is unaffected")

    -- facade-level: checkbox toggle no-ops inside the fence (the precision
    -- gate lives in lists_active(), shared by every single-cursor action),
    -- but works normally outside it.
    vim.api.nvim_win_set_cursor(0, { 4, 0 }) -- "- flag", inside the fence
    cascade.toggle_checkbox()
    vim.api.nvim_feedkeys("", "x", false)
    eq(vim.api.nvim_buf_get_lines(pbuf, 3, 4, false)[1], "- flag", "precision: checkbox toggle no-ops inside a fenced code block")

    vim.api.nvim_win_set_cursor(0, { 7, 0 }) -- "- outside the fence"
    cascade.toggle_checkbox()
    vim.api.nvim_feedkeys("", "x", false)
    eq(
      vim.api.nvim_buf_get_lines(pbuf, 6, 7, false)[1],
      "- [ ] outside the fence",
      "precision: checkbox toggle still works outside the fence"
    )
  end

  cfg.setup({})
end

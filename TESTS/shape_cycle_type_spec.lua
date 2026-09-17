-- TESTS/shape_cycle_type_spec.lua — `lists/shape.lua` (template decoding) and
-- `lists/cycle_type.lua` (per-item marker-type rotation).
--
-- `cycle_type` was the least covered module in the repo: the facade's
-- <leader>ct only ever reached its first few lines from `commands_spec`, so
-- the value-carrying, the wrap-around and the "current shape is not in the
-- cycle" branch were all unexercised. `shape` is its pure half and is driven
-- directly here, since every `cycle_type` decision is really a `shape`
-- decision.

return function(H)
  local eq = H.eq
  local ok = H.ok

  local shape = require("cascade.lists.shape")
  local cycle_type = require("cascade.lists.cycle_type")
  local marker = require("cascade.lists.marker")
  local cfg = require("cascade.config")

  -- ---------- shape.spec_of ----------

  do
    local s = shape.spec_of("1.")
    eq(s.kind, "digit", "spec_of '1.': kind")
    eq(s.delim, ".", "spec_of '1.': delim")
    eq(s.upper, false, "spec_of '1.': digits have no case")

    -- Any digit leads, not just 1 -- the template's digit is a placeholder.
    eq(shape.spec_of("7)").kind, "digit", "spec_of '7)': still digit")
    eq(shape.spec_of("7)").delim, ")", "spec_of '7)': delim")

    eq(shape.spec_of("a)").kind, "ascii", "spec_of 'a)': kind")
    eq(shape.spec_of("a)").upper, false, "spec_of 'a)': lowercase")
    eq(shape.spec_of("A.").kind, "ascii", "spec_of 'A.': kind")
    eq(shape.spec_of("A.").upper, true, "spec_of 'A.': uppercase")

    eq(shape.spec_of("i.").kind, "roman", "spec_of 'i.': kind")
    eq(shape.spec_of("i.").upper, false, "spec_of 'i.': lowercase")
    eq(shape.spec_of("I.").kind, "roman", "spec_of 'I.': kind")
    eq(shape.spec_of("I.").upper, true, "spec_of 'I.': uppercase")

    -- Anything else is an unordered bullet, and its delimiter is dropped:
    -- a bullet marker renders as "<bullet> ", never "<bullet><delim> ".
    local u = shape.spec_of("-")
    eq(u.kind, "unordered", "spec_of '-': kind")
    eq(u.bullet, "-", "spec_of '-': bullet char")
    eq(u.delim, "", "spec_of '-': no delimiter")
    eq(shape.spec_of("*").bullet, "*", "spec_of '*': bullet char")
    eq(shape.spec_of("+").bullet, "+", "spec_of '+': bullet char")
    -- A trailing character on a bullet template is discarded rather than
    -- becoming a delimiter.
    eq(shape.spec_of("->").bullet, "-", "spec_of '->': only the lead char counts")
    eq(shape.spec_of("->").delim, "", "spec_of '->': trailing text dropped")
  end

  -- ---------- shape.matches ----------

  do
    cfg.setup({ lists = { types = { "unordered", "digit", "ascii", "roman" } } })
    local lopts = cfg.get("lists")

    local digit = marker.parse("1. one", lopts)
    ok(shape.matches(digit, shape.spec_of("1.")), "matches: digit with '.' delim")
    ok(not shape.matches(digit, shape.spec_of("1)")), "matches: delimiter is part of the shape")
    ok(not shape.matches(digit, shape.spec_of("a.")), "matches: kind must agree")

    local bullet = marker.parse("- one", lopts)
    ok(shape.matches(bullet, shape.spec_of("-")), "matches: the right bullet char")
    ok(not shape.matches(bullet, shape.spec_of("*")), "matches: the wrong bullet char")

    -- Case is deliberately NOT part of matching: "a)" and "A)" are the same
    -- shape as far as the cycle is concerned, so a list written in one case
    -- still finds its position in a cycle configured with the other.
    local upper_alpha = marker.parse("B) two", lopts)
    ok(shape.matches(upper_alpha, shape.spec_of("a)")), "matches: case is not part of the shape")
  end

  -- ---------- shape.value_of / token_for ----------

  do
    cfg.setup({ lists = { types = { "unordered", "digit", "ascii", "roman" } } })
    local lopts = cfg.get("lists")

    eq(shape.value_of(marker.parse("3. x", lopts)), 3, "value_of: digit")
    eq(shape.value_of(marker.parse("c) x", lopts)), 3, "value_of: ascii")
    eq(shape.value_of(marker.parse("III. x", lopts)), 3, "value_of: roman")
    eq(shape.value_of(marker.parse("- x", lopts)), 1, "value_of: unordered falls back to 1")

    eq(shape.token_for(shape.spec_of("1."), 12), "12", "token_for: digit")
    eq(shape.token_for(shape.spec_of("a)"), 3), "c", "token_for: lowercase ascii")
    eq(shape.token_for(shape.spec_of("A)"), 3), "C", "token_for: uppercase ascii")
    eq(shape.token_for(shape.spec_of("i."), 4), "iv", "token_for: lowercase roman")
    eq(shape.token_for(shape.spec_of("I."), 4), "IV", "token_for: uppercase roman")
    eq(shape.token_for(shape.spec_of("*"), 9), "*", "token_for: unordered ignores the value")

    -- Out-of-range values fall back rather than returning nil into the
    -- renderer: roman numerals stop at 3999.
    eq(shape.token_for(shape.spec_of("I."), 5000), "I", "token_for: roman past 3999 falls back")
    eq(shape.token_for(shape.spec_of("a)"), 0), "a", "token_for: ascii below 1 falls back")
    eq(shape.token_for(shape.spec_of("A)"), 0), "A", "token_for: the fallback still takes the spec's case")
  end

  -- ---------- cycle_type.cycle ----------

  --- Cycle the single line `text` once and return the resulting line.
  ---@param text string
  ---@param dir integer
  ---@param opts table
  ---@return string line, boolean handled
  local function cycle_once(text, dir, opts)
    local buf = H.scratch("markdown")
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { text })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    local ctx = require("cascade.core.context").new(buf)
    local handled = cycle_type.cycle(ctx, opts, dir)
    return vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1], handled
  end

  do
    -- A ring every entry of which `types` can also parse back, so the cycle
    -- actually closes. (`types` has to list `ascii`, or an "a)" line stops
    -- being a list item -- see the shipped-defaults check at the end of this
    -- file, which now exercises the same round-trip with the real defaults.)
    cfg.setup({
      lists = {
        types = { "unordered", "digit", "ascii" },
        cycle = { "-", "*", "+", "1.", "a)" },
        renumber = { enable = false, on = {} },
      },
    })
    local lopts = cfg.get("lists")

    local line, handled = cycle_once("- item", 1, lopts)
    ok(handled, "cycle: a list line is handled")
    eq(line, "* item", "cycle forward: - -> *")
    eq(select(1, cycle_once("* item", 1, lopts)), "+ item", "cycle forward: * -> +")
    eq(select(1, cycle_once("+ item", 1, lopts)), "1. item", "cycle forward: + -> 1.")
    eq(select(1, cycle_once("1. item", 1, lopts)), "a) item", "cycle forward: 1. -> a)")
    -- Wrap-around, back to the first template.
    eq(select(1, cycle_once("a) item", 1, lopts)), "- item", "cycle forward: a) wraps to -")

    -- Backwards is the same ring in reverse, including the wrap.
    eq(select(1, cycle_once("- item", -1, lopts)), "a) item", "cycle back: - wraps to a)")
    eq(select(1, cycle_once("* item", -1, lopts)), "- item", "cycle back: * -> -")
    eq(select(1, cycle_once("1. item", -1, lopts)), "+ item", "cycle back: 1. -> +")
  end

  do
    -- `ascii` and `roman` overlap, and `types`' ORDER decides which wins:
    -- a single "I" is a valid Roman numeral *and* a valid alphabetic
    -- ordinal. With `ascii` first, "I." is read as the 9th letter; with
    -- `roman` first, as 1. That is documented behaviour (see
    -- config/DEFAULTS.lua's note on `sequence.types`) and the reason the ring
    -- above avoids mixing the two -- pinned here so a reordering is visible.
    cfg.setup({
      lists = { types = { "unordered", "digit", "ascii", "roman" }, renumber = { enable = false, on = {} } },
    })
    eq(marker.parse("I. x", cfg.get("lists")).kind, "ascii", "types order: ascii before roman reads 'I' as a letter")

    cfg.setup({
      lists = { types = { "unordered", "digit", "roman", "ascii" }, renumber = { enable = false, on = {} } },
    })
    eq(marker.parse("I. x", cfg.get("lists")).kind, "roman", "types order: roman before ascii reads 'I' as one")
    -- A letter that is not a Roman digit falls through to ascii either way.
    eq(marker.parse("g) x", cfg.get("lists")).kind, "ascii", "types order: 'g' is not a Roman digit")
    -- ... but one that is gets claimed by roman, value and all.
    eq(marker.parse("d) x", cfg.get("lists")).kind, "roman", "types order: 'd' IS a Roman digit (500)")
  end

  do
    -- The item's sequence value is carried into the next ordered shape, so
    -- cycling item 4 of a list does not reset it to 1.
    cfg.setup({
      lists = {
        types = { "unordered", "digit", "ascii", "roman" },
        cycle = { "1.", "a)", "I." },
        renumber = { enable = false, on = {} },
      },
    })
    local lopts = cfg.get("lists")

    eq(select(1, cycle_once("4. four", 1, lopts)), "d) four", "cycle: digit 4 carries into ascii 'd'")
    eq(select(1, cycle_once("d) four", 1, lopts)), "IV. four", "cycle: ascii 'd' carries into roman IV")
    eq(select(1, cycle_once("IV. four", 1, lopts)), "4. four", "cycle: roman IV carries back into digit 4")

    -- Indentation and trailing text are preserved untouched.
    eq(select(1, cycle_once("    2. deep", 1, lopts)), "    b) deep", "cycle: indent preserved")

    -- A checkbox survives the type change.
    cfg.setup({
      lists = {
        types = { "unordered", "digit", "ascii", "roman" },
        cycle = { "-", "1." },
        checkbox = { states = { " ", "x" } },
        renumber = { enable = false, on = {} },
      },
    })
    eq(select(1, cycle_once("- [x] done", 1, cfg.get("lists"))), "1. [x] done", "cycle: checkbox carried across the shape change")
  end

  do
    -- A marker whose shape is not in the configured cycle jumps to the first
    -- entry rather than being left alone.
    cfg.setup({
      lists = {
        types = { "unordered", "digit", "ascii", "roman" },
        cycle = { "1.", "a)" },
        renumber = { enable = false, on = {} },
      },
    })
    local lopts = cfg.get("lists")
    -- The unmatched index is forced to 1 and the direction is applied *after*
    -- that, so "jump to the first entry" really means "start from the first
    -- entry and step" -- forward lands on the second.
    eq(select(1, cycle_once("- stray", 1, lopts)), "a) stray", "cycle: a shape outside the ring starts from entry 1 and steps")
    -- Backwards from the forced index 1 wraps to the ring's last entry, which
    -- in a two-entry ring is the same one.
    eq(select(1, cycle_once("- stray", -1, lopts)), "a) stray", "cycle: outside the ring, backwards wraps to the last")

    cfg.setup({
      lists = {
        types = { "unordered", "digit", "ascii" },
        cycle = { "1.", "a)", "-" },
        renumber = { enable = false, on = {} },
      },
    })
    -- Three entries make the two directions distinguishable: forward from the
    -- forced index 1 is entry 2, backward is entry 3.
    eq(select(1, cycle_once("+ stray", 1, cfg.get("lists"))), "a) stray", "cycle: outside a 3-ring, forward is entry 2")
    eq(select(1, cycle_once("+ stray", -1, cfg.get("lists"))), "- stray", "cycle: outside a 3-ring, backward is entry 3")
  end

  do
    -- Refusals: no cycle configured, no marker, and a one-entry cycle whose
    -- rotation produces the identical line.
    cfg.setup({ lists = { cycle = {}, renumber = { enable = false, on = {} } } })
    local _, handled = cycle_once("- item", 1, cfg.get("lists"))
    ok(not handled, "cycle: an empty lists.cycle refuses")

    cfg.setup({
      lists = {
        types = { "unordered", "digit" },
        cycle = { "-", "*" },
        renumber = { enable = false, on = {} },
      },
    })
    local line2, handled2 = cycle_once("plain prose", 1, cfg.get("lists"))
    ok(not handled2, "cycle: a non-list line refuses")
    eq(line2, "plain prose", "cycle: a non-list line is untouched")

    cfg.setup({
      lists = {
        types = { "unordered", "digit" },
        cycle = { "-" },
        renumber = { enable = false, on = {} },
      },
    })
    local line3, handled3 = cycle_once("- item", 1, cfg.get("lists"))
    ok(not handled3, "cycle: a single-entry ring is a no-op, and says so")
    eq(line3, "- item", "cycle: the no-op leaves the line alone")
  end

  do
    -- With renumber-on-edit on, landing on an ordered shape re-sequences the
    -- block; landing on an unordered one must not (there is nothing to
    -- sequence, and the guard exists to skip the work).
    cfg.setup({
      lists = {
        types = { "unordered", "digit", "ascii", "roman" },
        cycle = { "1.", "-" },
        renumber = { enable = true, on = { "edit" } },
      },
    })
    local lopts = cfg.get("lists")

    local buf = H.scratch("markdown")
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "5. one", "5. two", "5. three" })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    -- Cycling line 1 to "-" leaves the siblings alone (unordered target).
    cycle_type.cycle(require("cascade.core.context").new(buf), lopts, 1)
    H.eq_lines(
      vim.api.nvim_buf_get_lines(buf, 0, -1, false),
      { "- one", "5. two", "5. three" },
      "cycle: an unordered target does not renumber the block"
    )

    local buf2 = H.scratch("markdown")
    vim.api.nvim_buf_set_lines(buf2, 0, -1, false, { "- one", "- two", "- three" })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    cycle_type.cycle(require("cascade.core.context").new(buf2), lopts, 1)
    H.eq_lines(
      vim.api.nvim_buf_get_lines(buf2, 0, -1, false),
      { "1. one", "- two", "- three" },
      "cycle: only the cursor line changes shape; renumber re-sequences what it finds"
    )
  end

  -- ---------- regression: the shipped defaults now round-trip ----------

  do
    -- `lists.cycle` defaults to { "-", "*", "+", "1.", "a)", "I." }, so
    -- `lists.types` has to recognize all four kinds those markers name
    -- (unordered/digit/ascii/roman) or cycling *produces* a shape the parser
    -- was never told to *read*: on the old `{ "unordered", "digit" }` default,
    -- <leader>ct walked - -> * -> + -> 1. -> a) and then dead-ended, and the
    -- "a)" line had silently stopped being a list item at all -- invisible to
    -- renumbering (manual, on-edit and on-save), <CR>/o/O continuation,
    -- checkbox toggling and the block transforms, with no cascade key able to
    -- put it back.
    cfg.setup({})
    local lopts = cfg.get("lists")

    H.eq_lines(
      lopts.types,
      { "unordered", "digit", "roman", "ascii" },
      "defaults: lists.types covers every kind lists.cycle can produce, roman before ascii"
    )
    H.eq_lines(lopts.cycle, { "-", "*", "+", "1.", "a)", "I." }, "defaults: lists.cycle as shipped")

    eq(select(1, cycle_once("- item", 1, lopts)), "* item", "defaults: step 1 works")
    eq(select(1, cycle_once("* item", 1, lopts)), "+ item", "defaults: step 2 works")
    eq(select(1, cycle_once("+ item", 1, lopts)), "1. item", "defaults: step 3 works")
    eq(select(1, cycle_once("1. item", 1, lopts)), "a) item", "defaults: step 4 reaches 'a)'")

    -- The ring now closes all the way round instead of dead-ending at 'a)'.
    local step5, handled5 = cycle_once("a) item", 1, lopts)
    eq(step5, "I. item", "defaults: step 5 reaches 'I.'")
    ok(handled5, "defaults: ...and reports handled")
    eq(select(1, cycle_once("I. item", 1, lopts)), "- item", "defaults: step 6 wraps back to '-'")
    eq(select(1, cycle_once("a) item", -1, lopts)), "1. item", "defaults: backwards from 'a)' reaches '1.'")

    -- Every shape cascade produces along the ring is still a list item.
    eq(marker.parse("a) item", lopts) ~= nil, true, "defaults: cascade's 'a)' output parses as a list item")
    eq(marker.parse("I. item", lopts) ~= nil, true, "defaults: cascade's 'I.' output parses too")

    -- The downstream fix, through the public facade: a list of "a)" items is
    -- visible to renumbering.
    -- `renumber.tree` regenerates each line's letter from its own running
    -- position, so a starting value of "g" for line 3 is rewritten to "c"
    -- (the correct next letter) rather than left alone -- this asserts the
    -- kind is recognized and renumbered at all, which is the point.
    local b = H.editable("markdown")
    vim.api.nvim_buf_set_lines(b, 0, -1, false, { "a) one", "b) two", "g) three" })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    require("cascade").renumber()
    H.eq_lines(
      vim.api.nvim_buf_get_lines(b, 0, -1, false),
      { "a) one", "b) two", "c) three" },
      "defaults: renumber recognizes and resequences an 'a)' list"
    )

    -- ... and to continuation.
    local ctx = require("cascade.core.context").new(b)
    vim.api.nvim_win_set_cursor(0, { 1, 6 })
    ok(require("cascade.lists.continue").cr(ctx, lopts), "defaults: <CR> continues a list cycle_type produced")

    -- The same defaults pair is fine for `lists.forms` (block rotation),
    -- whose every entry is a shape `types` can read -- which is what makes
    -- the `cycle` list's mismatch an oversight rather than a design.
    for _, tpl in ipairs(lopts.forms) do
      local kind = shape.spec_of(tpl).kind
      ok(kind == "unordered" or kind == "digit", ("defaults: lists.forms entry %q is a readable shape"):format(tpl))
    end
  end

  cfg.setup({})
end

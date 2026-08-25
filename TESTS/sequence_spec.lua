-- TESTS/sequence_spec.lua — renumbering inside a selection: the pure
-- scanner (kind lock, start mode, per-hit delimiter, prose boundaries) and the
-- two buffer entry points (linewise range, same-line charwise span).
---@diagnostic disable: missing-fields, need-check-nil, param-type-mismatch

return function(H)
  local eq = H.eq
  local eq_lines = H.eq_lines
  local seq = require("cascade.sequence.renumber")
  local cfg = require("cascade.config")

  local KEEP = { enable = true, start = "keep", types = { "digit", "ascii", "roman" } }
  local ONE = { enable = true, start = "one", types = { "digit", "ascii", "roman" } }

  ---@param text string
  ---@param opts table
  ---@return string
  local function rw(text, opts)
    return (seq.rewrite(text, opts, {}))
  end

  -- ---------- pure scanner ----------

  -- motivating case 2: inline numbers mid-prose, no list context at all.
  eq(
    rw("te 4. text der nur als 5. beispiel 9. um wa", KEEP),
    "te 4. text der nur als 5. beispiel 6. um wa",
    "inline: keep starts at the first hit"
  )
  eq(
    rw("te 4. text der nur als 5. beispiel 9. um wa", ONE),
    "te 1. text der nur als 2. beispiel 3. um wa",
    "inline: one restarts at 1"
  )

  -- the delimiter is kept per hit, not unified on the first one.
  eq(rw("7. a 3) b 2. c", KEEP), "7. a 8) b 9. c", "delimiter preserved per hit")

  -- prose boundaries: decimals, versions and abbreviations are not ordinals.
  eq(rw("pi is 3.14 and 5. is next", KEEP), "pi is 3.14 and 5. is next", "decimal is not an ordinal")
  eq(rw("v1.2 then 4. x", KEEP), "v1.2 then 4. x", "version token is not an ordinal")
  eq(rw("2. see 3.4 and 8. end", KEEP), "2. see 3.4 and 3. end", "decimal skipped mid-sequence")

  -- the first hit locks the kind: an alpha marker inside a digit run is left
  -- alone rather than folded into the same sequence.
  eq(rw("1. x a) y 5. z", KEEP), "1. x a) y 2. z", "kind lock: alpha untouched in a digit run")

  -- alpha and roman runs, case preserved from each hit.
  eq(rw("a) x c) y f) z", KEEP), "a) x b) y c) z", "alpha run")
  eq(rw("C. x C. y", KEEP), "C. x D. y", "alpha run keeps UPPER case")
  eq(rw("ii. x ix. y", KEEP), "ii. x iii. y", "roman run (multi-letter is never alpha)")
  eq(rw("II. x IX. y", KEEP), "II. x III. y", "roman run keeps UPPER case")

  -- types order decides the ambiguous single-letter case.
  local ROMAN_FIRST = { enable = true, start = "keep", types = { "digit", "roman", "ascii" } }
  eq(rw("i. x i. y", ROMAN_FIRST), "i. x ii. y", "roman before ascii: single 'i' reads as roman 1")
  eq(rw("i. x i. y", KEEP), "i. x j. y", "ascii before roman: single 'i' reads as letter 9")

  -- nothing to do: text comes back byte-identical.
  eq(rw("just some prose without ordinals", KEEP), "just some prose without ordinals", "no hits: unchanged")

  -- rewrite reports how many tokens it replaced.
  local _, n = seq.rewrite("1. a 1. b 1. c", KEEP, {})
  eq(n, 3, "rewrite returns the hit count")

  -- shared state carries one sequence across several strings (how `range`
  -- walks a multi-line selection).
  local state = {}
  local l1 = seq.rewrite("### 2. iwas", KEEP, state)
  local l2 = seq.rewrite("### 3. sad", KEEP, state)
  eq(l1, "### 2. iwas", "carried state: first line keeps its start value")
  eq(l2, "### 3. sad", "carried state: second line continues the run")
  eq(state.kind, "digit", "carried state: kind committed on the first hit")

  -- ---------- buffer: linewise range ----------

  local buf = H.scratch("markdown")

  -- motivating case 1: numbered headlines, only the selected block renumbered.
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    "### 7. keep me",
    "### 2. iwas",
    "prose in between",
    "### 3. sad",
    "### 9. more",
    "### 4. keep me too",
  })
  eq(seq.range(buf, 1, 4, KEEP), true, "range: reports a change")
  eq_lines(vim.api.nvim_buf_get_lines(buf, 0, -1, false), {
    "### 7. keep me",
    "### 2. iwas",
    "prose in between",
    "### 3. sad",
    "### 4. more",
    "### 4. keep me too",
  }, "range: only the selected rows are renumbered, prose lines pass through")

  -- start = "one" over the same block.
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "### 7. a", "### 2. b", "### 9. c" })
  seq.range(buf, 0, 2, ONE)
  eq_lines(vim.api.nvim_buf_get_lines(buf, 0, -1, false), { "### 1. a", "### 2. b", "### 3. c" }, "range: start = one")

  -- no ordinals in range: no write, reported as unchanged.
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "plain", "lines" })
  eq(seq.range(buf, 0, 1, KEEP), false, "range: no hits, no change")

  -- ---------- buffer: same-line charwise span ----------

  -- only the selected byte range is touched; the rest of the line is not.
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "1. outside te 4. text als 5. bsp 9. um wa" })
  local line = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1]
  local scol = line:find("te ", 1, true) - 1
  local ecol = #line - 1
  local changed, new_ecol = seq.span(buf, 0, scol, ecol, KEEP)
  eq(changed, true, "span: reports a change")
  eq(
    vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1],
    "1. outside te 4. text als 5. bsp 6. um wa",
    "span: leading '1.' outside the selection is untouched"
  )
  eq(new_ecol, ecol, "span: end column follows the rewritten text (9. -> 6. keeps its width)")

  -- widening replacement (9. -> 10.) reports a larger end column.
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "x 9. a 1. b" })
  local _, wide_ecol = seq.span(buf, 0, 2, 10, KEEP)
  eq(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1], "x 9. a 10. b", "span: sequence widens the line")
  eq(wide_ecol, 11, "span: end column follows the widened text")

  -- ---------- buffer: multi-line charwise span ----------

  -- the motivating headline case, selected mid-line on both ends: only the
  -- part of each boundary line inside the selection is touched. Row 0's
  -- "7." sits *before* the selection start and must survive untouched even
  -- though it looks exactly like an ordinal; row 3's "9." sits inside the
  -- selection (its " tail" suffix does not) and is the one real rewrite.
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    "before ### 7. keep me",
    "### 2. iwas",
    "prose in between",
    "### 9. sad tail",
  })
  do
    local first = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1]
    local scol = first:find("keep", 1, true) - 1 -- selection starts at "keep", after "7. "
    local last = vim.api.nvim_buf_get_lines(buf, 3, 4, false)[1]
    local ecol = last:find("sad", 1, true) + #"sad" - 2 -- selection ends inside "sad", before " tail"
    local changed, new_ecol = seq.span_multi(buf, 0, scol, 3, ecol, KEEP)
    eq(changed, true, "span_multi: reports a change")
    eq_lines(vim.api.nvim_buf_get_lines(buf, 0, -1, false), {
      "before ### 7. keep me",
      "### 2. iwas",
      "prose in between",
      "### 3. sad tail",
    }, "span_multi: the out-of-selection '7.' survives, the in-selection '9.' becomes '3.'")
    eq(new_ecol, ecol, "span_multi: end column unchanged when the width doesn't change")
  end

  -- start = "one" forces a real rewrite, and only the selected slice of the
  -- boundary lines is affected -- the untouched prefix/suffix survive as-is.
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    "before ### 7. keep me",
    "### 2. iwas",
    "prose in between",
    "### 9. sad tail",
  })
  do
    local first = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1]
    local scol = first:find("keep", 1, true) - 1
    local last = vim.api.nvim_buf_get_lines(buf, 3, 4, false)[1]
    local ecol = last:find("sad", 1, true) + #"sad" - 2
    local changed = seq.span_multi(buf, 0, scol, 3, ecol, ONE)
    eq(changed, true, "span_multi one: reports a change")
    eq_lines(vim.api.nvim_buf_get_lines(buf, 0, -1, false), {
      "before ### 7. keep me",
      "### 1. iwas",
      "prose in between",
      "### 2. sad tail",
    }, "span_multi one: only the selected part of each boundary line is renumbered")
  end

  -- widening on the last line's selected part is reported back.
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "x 1. a", "y 9. b tail" })
  do
    local last = vim.api.nvim_buf_get_lines(buf, 1, 2, false)[1]
    local ecol = last:find("9%.") -- byte index of "9" itself (1-based == 0-based end of "9")
    local _, new_ecol = seq.span_multi(buf, 0, 2, 1, ecol, KEEP)
    eq(vim.api.nvim_buf_get_lines(buf, 0, -1, false)[2], "y 2. b tail", "span_multi: last-line width change applied")
    eq(new_ecol, ecol, "span_multi: digit->digit keeps the same width here")
  end

  -- no hits anywhere in the span: reported unchanged, buffer untouched.
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "plain one", "plain two", "plain three" })
  local no_changed = seq.span_multi(buf, 0, 2, 2, 3, KEEP)
  eq(no_changed, false, "span_multi: no hits, no change")

  -- too few lines to be a real multi-line span: refuses rather than
  -- misreading a single line as both "first" and "last".
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "1. only line" })
  eq(seq.span_multi(buf, 0, 0, 0, 5, KEEP), false, "span_multi: single-row range is a no-op, not a partial rewrite")

  -- ---------- config + facade wiring ----------

  cfg.setup({})
  local defaults = cfg.get("sequence")
  eq(defaults.enable, true, "config: sequence enabled by default")
  eq(defaults.start, "keep", "config: default start mode")
  eq(table.concat(defaults.types, ","), "digit,ascii,roman", "config: default types")

  -- malformed values degrade to the documented defaults instead of erroring.
  cfg.setup({ sequence = { start = "nonsense", types = {} } })
  eq(cfg.get("sequence").start, "keep", "config: unknown start mode falls back to keep")
  eq(table.concat(cfg.get("sequence").types, ","), "digit,ascii,roman", "config: empty types falls back")

  local cascade = require("cascade")
  cascade.setup({})
  eq(type(cascade.renumber_selection), "function", "facade: renumber_selection exposed")

  -- :Cascade renumber selection routes into the sequence domain (linewise).
  local cbuf = H.editable("markdown")
  vim.api.nvim_buf_set_lines(cbuf, 0, -1, false, { "### 7. a", "### 2. b" })
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  vim.cmd("1,2Cascade renumber selection")
  eq_lines(
    vim.api.nvim_buf_get_lines(cbuf, 0, -1, false),
    { "### 7. a", "### 8. b" },
    ":Cascade renumber selection renumbers the range's inline numbers"
  )

  -- the switch really switches it off.
  cascade.setup({ sequence = { enable = false } })
  vim.api.nvim_buf_set_lines(cbuf, 0, -1, false, { "### 7. a", "### 2. b" })
  vim.cmd("1,2Cascade renumber selection")
  eq_lines(
    vim.api.nvim_buf_get_lines(cbuf, 0, -1, false),
    { "### 7. a", "### 2. b" },
    "sequence.enable = false makes the command a no-op"
  )

  cascade.setup({})

  -- renumber_selection() through a genuine multi-line charwise (`v`)
  -- Visual selection -- the keymap path `<leader>cR` actually drives, not
  -- just the linewise Ex-command shortcut tested above. A Visual selection
  -- only exists while Vim is actually IN Visual mode (`mode() == "v"`), so
  -- this enters it with `:normal! v` and no trailing <Esc> rather than the
  -- usual "set marks, then Esc" trick.
  do
    local function flush()
      vim.api.nvim_feedkeys("", "x", false)
    end
    local function esc()
      vim.cmd("normal! \27")
    end

    vim.api.nvim_buf_set_lines(cbuf, 0, -1, false, {
      "before ### 7. keep me",
      "### 2. iwas",
      "prose in between",
      "### 9. sad tail",
    })
    local first = vim.api.nvim_buf_get_lines(cbuf, 0, 1, false)[1]
    local scol = first:find("keep", 1, true) - 1 -- 0-based
    local last = vim.api.nvim_buf_get_lines(cbuf, 3, 4, false)[1]
    local ecol = last:find("sad", 1, true) + #"sad" - 2 -- 0-based inclusive

    vim.api.nvim_win_set_cursor(0, { 1, scol })
    vim.cmd("normal! v")
    vim.api.nvim_win_set_cursor(0, { 4, ecol })
    cascade.renumber_selection()
    flush()

    eq_lines(vim.api.nvim_buf_get_lines(cbuf, 0, -1, false), {
      "before ### 7. keep me",
      "### 2. iwas",
      "prose in between",
      "### 3. sad tail",
    }, "renumber_selection: real multi-line charwise Visual selection, boundary text untouched")
    eq(vim.fn.mode(), "v", "renumber_selection: leaves charwise Visual active")
    local rsrow, rscol, rerow, recol = require("lib.nvim.selection").chars_multiline()
    eq(rsrow, 0, "renumber_selection: reselected srow")
    eq(rscol, scol, "renumber_selection: reselected scol")
    eq(rerow, 3, "renumber_selection: reselected erow")
    eq(recol, ecol, "renumber_selection: reselected ecol (no width change here)")
    esc()
  end
end

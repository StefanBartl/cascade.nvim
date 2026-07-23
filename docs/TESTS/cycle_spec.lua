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

  -- cascade.cycle.date: pure span/step behavior.
  local date = require("cascade.cycle.date")

  local ds, de, dtext = date.span("2024-01-31", 0)
  eq(ds, 0, "date.span: start")
  eq(de, 10, "date.span: end")
  eq(dtext, "2024-01-31", "date.span: full match")
  eq(select(1, date.span("count = 41", 8)), nil, "date.span: no match on plain digits")
  eq(select(1, date.span("see 2024-01-31 today", 17)), nil, "date.span: cursor outside the date")

  local _, _, day_repl = date.step("2024-01-31", 8, 1) -- cursor on "31" (day)
  eq(day_repl, "2024-02-01", "date.step: day rolls over past the end of the month")

  local _, _, month_repl = date.step("2024-01-31", 5, 1) -- cursor on "01" (month)
  eq(month_repl, "2024-03-02", "date.step: month rolls over, day normalizes via a leap Feb")

  local _, _, year_repl = date.step("2024-01-31", 0, 1) -- cursor on "2024" (year)
  eq(year_repl, "2025-01-31", "date.step: year increments, day/month unaffected")

  local _, _, year_back = date.step("2024-01-31", 0, -1)
  eq(year_back, "2023-01-31", "date.step: year decrements")

  local _, _, leap_repl = date.step("2024-02-29", 0, 1) -- Feb 29 into a non-leap year
  eq(leap_repl, "2025-03-01", "date.step: year increment across a leap-day rolls into March")

  eq(select(1, date.step("plain text", 0, 1)), nil, "date.step: nil when not on a date")

  -- Facade-level: +/- steps the date segment under the cursor, with
  -- calendar-aware rollover that native <C-a>/<C-x> can't do (it would
  -- produce the invalid "2024-01-32").
  vim.api.nvim_buf_set_lines(ebuf, 0, -1, false, { "due: 2024-01-31" })
  vim.api.nvim_win_set_cursor(0, { 1, #"due: 2024-01-" }) -- on the day "31"
  cascade.increment()
  flush()
  eq(vim.api.nvim_buf_get_lines(ebuf, 0, 1, false)[1], "due: 2024-02-01", "+ on a date rolls the day over into the next month")
  cascade.decrement()
  flush()
  eq(vim.api.nvim_buf_get_lines(ebuf, 0, 1, false)[1], "due: 2024-01-31", "- undoes it back to the last day of January")

  -- features.date = false disables it; a date's day segment then falls
  -- through to native <C-a>, which misreads the preceding "-" as a minus
  -- sign (nrformats) and decrements instead -- exactly the broken behavior
  -- cascade's date feature exists to avoid.
  cfg.setup({ cycle = { features = { date = false } } })
  vim.api.nvim_buf_set_lines(ebuf, 0, -1, false, { "due: 2024-01-31" })
  vim.api.nvim_win_set_cursor(0, { 1, #"due: 2024-01-" })
  cascade.increment()
  flush()
  eq(
    vim.api.nvim_buf_get_lines(ebuf, 0, 1, false)[1],
    "due: 2024-01-30",
    "features.date = false: native <C-a> misreads the '-' as a sign and decrements"
  )

  cfg.setup({})

  -- token.operator_span: pure literal-position matching against groups,
  -- distinct from token.span's 'iskeyword' scan.
  local token = require("cascade.cycle.token")
  local op_groups = cfg.get("cycle").groups -- default groups include the operator flips

  local eq_s, eq_e, eq_text = token.operator_span("if (a == b) then", 6, op_groups) -- cursor on first "="
  eq(eq_s, 6, "operator_span: == start")
  eq(eq_e, 8, "operator_span: == end")
  eq(eq_text, "==", "operator_span: == matched")

  eq(select(1, token.operator_span("local x = true", 8, op_groups)), nil, "operator_span: word entries never match")
  eq(select(1, token.operator_span("plain text", 3, op_groups)), nil, "operator_span: no operator present")

  -- longest-match preference: a group containing both "<" and "<=" should
  -- resolve to the longer "<=" when the cursor sits on it.
  local pref_groups = { { "<", ">" }, { "<=", ">=" } }
  local le_s, le_e, le_text = token.operator_span("if a <= b", 5, pref_groups)
  eq(le_s, 5, "operator_span: prefers the longer match (start)")
  eq(le_e, 7, "operator_span: prefers the longer match (end)")
  eq(le_text, "<=", "operator_span: prefers the longer match (<=, not <)")

  -- Facade-level: +/- flips the operator group entry under the cursor,
  -- same as word/date, via the same dot-repeatable +/- keys.
  cfg.setup({})

  vim.api.nvim_buf_set_lines(ebuf, 0, -1, false, { "if (a == b) then" })
  vim.api.nvim_win_set_cursor(0, { 1, 7 }) -- on "=="
  cascade.increment()
  flush()
  eq(vim.api.nvim_buf_get_lines(ebuf, 0, 1, false)[1], "if (a != b) then", "+ flips == to !=")
  cascade.decrement()
  flush()
  eq(vim.api.nvim_buf_get_lines(ebuf, 0, 1, false)[1], "if (a == b) then", "- flips != back to ==")

  vim.api.nvim_buf_set_lines(ebuf, 0, -1, false, { "a && b" })
  vim.api.nvim_win_set_cursor(0, { 1, 2 }) -- on "&&"
  cascade.increment()
  flush()
  eq(vim.api.nvim_buf_get_lines(ebuf, 0, 1, false)[1], "a || b", "+ flips && to ||")

  vim.api.nvim_buf_set_lines(ebuf, 0, -1, false, { "a < b" })
  vim.api.nvim_win_set_cursor(0, { 1, 2 }) -- on "<"
  cascade.increment()
  flush()
  eq(vim.api.nvim_buf_get_lines(ebuf, 0, 1, false)[1], "a > b", "+ flips < to >")

  vim.api.nvim_buf_set_lines(ebuf, 0, -1, false, { "x + y" })
  vim.api.nvim_win_set_cursor(0, { 1, 2 }) -- on the standalone "+"
  cascade.increment()
  flush()
  eq(vim.api.nvim_buf_get_lines(ebuf, 0, 1, false)[1], "x - y", "+ flips a standalone + to -")

  -- word_cycle.pick: interactive picker over the cursor's cycle group.
  -- vim.ui.select is stubbed synchronously here (the real UI is interactive;
  -- Telescope backs it automatically if the user has telescope-ui-select.nvim
  -- registered as the vim.ui.select handler -- cascade just calls the
  -- standard API and doesn't need to know which backend answers it).
  local word_cycle = require("cascade.cycle.word_cycle")
  local Context = require("cascade.core.context")
  local orig_select = vim.ui.select
  local seen_items, choice_idx

  vim.ui.select = function(items, _, on_choice)
    seen_items = items
    on_choice(items[choice_idx])
  end

  vim.api.nvim_buf_set_lines(ebuf, 0, -1, false, { "flag = true" })
  vim.api.nvim_win_set_cursor(0, { 1, 7 })
  choice_idx = 2 -- "false"
  local picked = word_cycle.pick(Context.new(), cfg.get("cycle"))
  eq(picked, true, "pick: handled when a group is found")
  eq(vim.api.nvim_buf_get_lines(ebuf, 0, 1, false)[1], "flag = false", "pick: replaces with the chosen entry")
  eq(table.concat(seen_items, ","), "true,false", "pick: shows every entry in the group")

  -- operator groups go through the picker too, replaced verbatim (no case shape).
  vim.api.nvim_buf_set_lines(ebuf, 0, -1, false, { "if (a == b) then" })
  vim.api.nvim_win_set_cursor(0, { 1, 7 })
  choice_idx = 2 -- "!="
  word_cycle.pick(Context.new(), cfg.get("cycle"))
  eq(vim.api.nvim_buf_get_lines(ebuf, 0, 1, false)[1], "if (a != b) then", "pick: works for operator groups too")

  -- off a cyclable token: returns false and never opens the picker.
  local select_called = false
  vim.ui.select = function()
    select_called = true
  end
  vim.api.nvim_buf_set_lines(ebuf, 0, -1, false, { "plain text" })
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  local not_picked = word_cycle.pick(Context.new(), cfg.get("cycle"))
  eq(not_picked, false, "pick: returns false off a cyclable token")
  eq(select_called, false, "pick: never opens the picker when there's nothing to pick")

  -- facade-level: cascade.cycle_pick() (bound to <leader>cp in the preset).
  vim.ui.select = function(items, _, on_choice)
    on_choice(items[2])
  end
  vim.api.nvim_buf_set_lines(ebuf, 0, -1, false, { "flag = true" })
  vim.api.nvim_win_set_cursor(0, { 1, 7 })
  cascade.cycle_pick()
  eq(vim.api.nvim_buf_get_lines(ebuf, 0, 1, false)[1], "flag = false", "cascade.cycle_pick replaces via the picker")

  vim.ui.select = orig_select

  cfg.setup({})
end

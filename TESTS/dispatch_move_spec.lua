-- TESTS/dispatch_move_spec.lua — `cascade.dispatch` and `lists/move.lua`'s
-- range half, plus the one branch `lists/checkbox.lua` had left.
--
-- Three small leaf gaps the measured line coverage pointed at, grouped because
-- each is a handful of assertions rather than a file's worth:
--
--   * `dispatch.try_or_native` had no coverage at all -- it is the second half
--     of cascade's detect -> advance -> fallback contract, and the half that
--     decides whether an unhandled key keeps its native meaning.
--   * `move.selection` (the visual-mode move) was never called; only
--     `move.line` was. It does its own boundary arithmetic and its own
--     reselect, neither shared with `move.line`.
--   * `checkbox.toggle`'s "current state is not in `checkbox.states`" branch,
--     which is how a checkbox written by another tool re-enters the cycle.

return function(H)
  local eq = H.eq
  local ok = H.ok
  local eq_lines = H.eq_lines

  local cfg = require("cascade.config")
  local dispatch = require("cascade.dispatch")
  local move = require("cascade.lists.move")
  local checkbox = require("cascade.lists.checkbox")
  local Context = require("cascade.core.context")

  cfg.setup({})

  -- ---------- dispatch.try ----------

  do
    local calls = {}
    local handled = dispatch.try({
      function()
        calls[#calls + 1] = 1
        return false
      end,
      function()
        calls[#calls + 1] = 2
        return true
      end,
      function()
        calls[#calls + 1] = 3
        return true
      end,
    })
    ok(handled, "dispatch.try: reports handled when one handler claims it")
    eq_lines(vim.tbl_map(tostring, calls), { "1", "2" }, "dispatch.try: stops at the first handler that claims it")
  end

  do
    local handled = dispatch.try({
      function()
        return false
      end,
      function()
        return nil
      end,
    })
    ok(not handled, "dispatch.try: no handler claiming it reports unhandled")
    ok(not dispatch.try({}), "dispatch.try: an empty handler list reports unhandled")
  end

  do
    -- A throwing handler is caught and treated as "did not handle", so one bad
    -- handler cannot break the chain or escape into a keymap callback.
    local reached_next = false
    local handled = dispatch.try({
      function()
        error("simulated handler failure")
      end,
      function()
        reached_next = true
        return true
      end,
    })
    ok(handled, "dispatch.try: a throwing handler does not abort the chain")
    ok(reached_next, "dispatch.try: the next handler still runs")
  end

  do
    -- A handler returning a truthy non-boolean does NOT count as handled: the
    -- contract is `handled == true`, checked with `ok and handled`, so a
    -- handler that accidentally returns a value is... in fact accepted, since
    -- `ok and handled` is truthy. Pinned as the actual behaviour.
    local handled = dispatch.try({
      function()
        return "yes" ---@diagnostic disable-line: return-type-mismatch
      end,
    })
    ok(handled, "dispatch.try: any truthy return counts as handled")
  end

  do
    -- The context is built once and passed to every handler, rather than each
    -- handler re-reading the cursor.
    local b = H.editable("markdown")
    vim.api.nvim_buf_set_lines(b, 0, -1, false, { "- one" })
    vim.api.nvim_win_set_cursor(0, { 1, 3 })
    local seen = {}
    dispatch.try({
      function(c)
        seen[#seen + 1] = c
        return false
      end,
      function(c)
        seen[#seen + 1] = c
        return false
      end,
    })
    eq(#seen, 2, "dispatch.try: both handlers ran")
    ok(seen[1] == seen[2], "dispatch.try: the same context object reaches every handler")
    eq(seen[1].line, "- one", "dispatch.try: the context carries the cursor line")
    eq(seen[1].col0, 3, "dispatch.try: ... and the byte column")

    -- An explicitly supplied context is reused rather than rebuilt.
    local mine = Context.new(b)
    local got
    dispatch.try({
      function(c)
        got = c
        return true
      end,
    }, mine)
    ok(got == mine, "dispatch.try: a supplied context is passed through untouched")
  end

  -- ---------- dispatch.try_or_native ----------

  do
    -- Handled: the native key must NOT be fed. Driven in a real buffer so a
    -- leaked keystroke would be visible as a buffer change.
    local b = H.editable("markdown")
    vim.api.nvim_buf_set_lines(b, 0, -1, false, { "abc" })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    local handled = dispatch.try_or_native({
      function()
        return true
      end,
    }, "x")
    vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "x", false) -- flush anything queued
    ok(handled, "try_or_native: reports handled")
    eq_lines(
      vim.api.nvim_buf_get_lines(b, 0, -1, false),
      { "abc" },
      "try_or_native: a handled action does not feed the native key"
    )
  end

  do
    -- Unhandled: the native key IS fed, keeping the editor's default. `x`
    -- deletes the character under the cursor, which is unmistakable.
    local b = H.editable("markdown")
    vim.api.nvim_buf_set_lines(b, 0, -1, false, { "abc" })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    local handled = dispatch.try_or_native({
      function()
        return false
      end,
    }, "x")
    vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "x", false) -- the fallback is queued, not immediate
    ok(not handled, "try_or_native: reports unhandled")
    eq_lines(vim.api.nvim_buf_get_lines(b, 0, -1, false), { "bc" }, "try_or_native: the native key really was fed")
  end

  do
    -- With `debug` on, both entry points log through `util.lib.debug_log`
    -- instead of staying silent -- the one place that decision is observable
    -- without lib.nvim.logger is vim.notify at DEBUG level, which is the
    -- documented fallback.
    cfg.setup({ debug = true })
    local saved = package.loaded["lib.nvim.logger"]
    package.loaded["lib.nvim.logger"] = nil
    package.preload["lib.nvim.logger"] = function()
      error("simulated: lib.nvim.logger not installed")
    end
    -- The logger probe is cached on first use, so re-require the bridge to
    -- make this case independent of whatever ran before it.
    package.loaded["cascade.util.lib"] = nil
    package.loaded["cascade.dispatch"] = nil
    local fresh = require("cascade.dispatch")

    local levels = {}
    local orig = vim.notify
    -- Test double over a typed surface; restored right after the call.
    ---@diagnostic disable-next-line: duplicate-set-field
    vim.notify = function(msg, level)
      levels[#levels + 1] = { msg = tostring(msg), level = level }
    end
    fresh.try({
      function()
        return false
      end,
    })
    vim.notify = orig

    package.preload["lib.nvim.logger"] = nil
    package.loaded["lib.nvim.logger"] = saved
    package.loaded["cascade.util.lib"] = nil
    package.loaded["cascade.dispatch"] = nil

    ok(#levels >= 2, "dispatch: debug = true logs the handler attempt and the miss")
    eq(levels[1].level, vim.log.levels.DEBUG, "dispatch: the debug fallback logs at DEBUG level")
    local joined = ""
    for _, entry in ipairs(levels) do
      joined = joined .. entry.msg .. "\n"
    end
    ok(joined:find("dispatch.try: handler tried", 1, true) ~= nil, "dispatch: each handler attempt is logged")
    ok(joined:find("no handler matched", 1, true) ~= nil, "dispatch: the miss is logged")

    cfg.setup({})
    -- With debug off again, nothing is notified at all (the cheap boolean).
    local quiet = 0
    local orig2 = vim.notify
    ---@diagnostic disable-next-line: duplicate-set-field
    vim.notify = function()
      quiet = quiet + 1
    end
    require("cascade.dispatch").try({
      function()
        return false
      end,
    })
    vim.notify = orig2
    eq(quiet, 0, "dispatch: debug = false logs nothing")
  end

  -- ---------- move.selection ----------

  do
    cfg.setup({})
    local opts = cfg.get("lists")
    local b = H.editable("markdown")

    vim.api.nvim_buf_set_lines(b, 0, -1, false, { "a", "b", "c", "d" })
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    ok(move.selection(b, 1, 2, 1, opts), "move.selection: moving down reports handled")
    eq_lines(vim.api.nvim_buf_get_lines(b, 0, -1, false), { "a", "d", "b", "c" }, "move.selection: rows 2-3 moved down by one")

    vim.api.nvim_buf_set_lines(b, 0, -1, false, { "a", "b", "c", "d" })
    vim.api.nvim_win_set_cursor(0, { 3, 0 })
    ok(move.selection(b, 2, 3, -1, opts), "move.selection: moving up reports handled")
    eq_lines(vim.api.nvim_buf_get_lines(b, 0, -1, false), { "a", "c", "d", "b" }, "move.selection: rows 3-4 moved up by one")

    -- Boundaries: refused rather than erroring, and the buffer is untouched.
    vim.api.nvim_buf_set_lines(b, 0, -1, false, { "a", "b", "c" })
    ok(not move.selection(b, 0, 1, -1, opts), "move.selection: refuses to move the first row up")
    eq_lines(vim.api.nvim_buf_get_lines(b, 0, -1, false), { "a", "b", "c" }, "move.selection: ... leaving the buffer alone")
    ok(not move.selection(b, 1, 2, 1, opts), "move.selection: refuses to move the last row down")
    eq_lines(vim.api.nvim_buf_get_lines(b, 0, -1, false), { "a", "b", "c" }, "move.selection: ... leaving the buffer alone")
  end

  do
    -- A moved ordered block is re-sequenced afterwards, which is the whole
    -- reason this wraps `:move` instead of the plain `:m` mapping. Moving an
    -- item that is NOT the block's first leaves the numbering alone.
    cfg.setup({ lists = { renumber = { enable = true, on = { "edit" } } } })
    local opts = cfg.get("lists")
    local b = H.editable("markdown")
    vim.api.nvim_buf_set_lines(b, 0, -1, false, { "1. one", "2. two", "3. three", "4. four" })
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    move.selection(b, 1, 1, 1, opts)
    eq_lines(
      vim.api.nvim_buf_get_lines(b, 0, -1, false),
      { "1. one", "2. three", "3. two", "4. four" },
      "move.selection: the markers are re-sequenced after the move"
    )

    -- With renumber-on-edit off, the markers travel with their lines instead.
    cfg.setup({ lists = { renumber = { enable = false, on = {} } } })
    local opts2 = cfg.get("lists")
    vim.api.nvim_buf_set_lines(b, 0, -1, false, { "1. one", "2. two", "3. three" })
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    move.selection(b, 1, 1, 1, opts2)
    eq_lines(
      vim.api.nvim_buf_get_lines(b, 0, -1, false),
      { "1. one", "3. three", "2. two" },
      "move.selection: no renumber trigger means the markers move with the text"
    )
    cfg.setup({})
  end

  -- ---------- regression: moving an item into first position no longer
  -- ---------- inflates the whole block's numbering

  do
    -- `renumber.tree`'s base level deliberately keeps "its first item's start
    -- offset", so a list authored as `5. 6. 7.` stays anchored at 5. That
    -- assumption -- the first line's marker is the author's intended start --
    -- used to break on any edit that changes WHICH line is first, and `move`
    -- is exactly such an edit: after moving item 1 down, the line then
    -- standing first carried marker "2", so the block was re-sequenced from 2,
    -- drifting upward once per keypress -- and nothing repaired it, since
    -- both the on-save `renumber.all` and the manual `:Cascade renumber`
    -- anchor on the same (now wrong) first marker.
    --
    -- Notably NOT affected even before the fix: `sort`, `reverse` and
    -- `:Cascade sort` reorder the same lines and keep 1, 2, 3 -- they re-emit
    -- the markers themselves instead of going through `tree`. So this was
    -- `lists/move.lua`'s defect, not `renumber`'s.
    --
    -- Fixed by having `move` capture the block's base start value BEFORE the
    -- `:move` (`renumber.peek_base_start`) and pass it through as `tree`'s
    -- `forced_base_start`, rather than letting `tree` re-derive it from
    -- whichever line ends up first after the reorder. Simply forcing a
    -- restart at 1 would have been wrong -- it would renumber a
    -- deliberately-authored `5. 6. 7.` list down to `1. 2. 3.` (pinned below).
    cfg.setup({})
    local opts = cfg.get("lists")
    local b = H.editable("markdown")

    -- Moving the first item down keeps the block anchored at 1.
    vim.api.nvim_buf_set_lines(b, 0, -1, false, { "1. one", "2. two", "3. three", "4. four" })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    move.selection(b, 0, 0, 1, opts)
    eq_lines(
      vim.api.nvim_buf_get_lines(b, 0, -1, false),
      { "1. two", "2. one", "3. three", "4. four" },
      "moving the first item down keeps the block anchored at 1"
    )

    -- ... and again: no drift, however often it is repeated.
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    move.selection(b, 0, 0, 1, opts)
    eq_lines(
      vim.api.nvim_buf_get_lines(b, 0, -1, false),
      { "1. one", "2. two", "3. three", "4. four" },
      "...and stays anchored at 1 on repeat moves"
    )

    -- Moving the second item UP has the same fix applied, since it too ends
    -- up first.
    vim.api.nvim_buf_set_lines(b, 0, -1, false, { "1. one", "2. two", "3. three" })
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    move.selection(b, 1, 1, -1, opts)
    eq_lines(
      vim.api.nvim_buf_get_lines(b, 0, -1, false),
      { "1. two", "2. one", "3. three" },
      "moving the second item up keeps the block anchored at 1 too"
    )

    -- The repair paths were never the right fix (the anchor capture in move
    -- itself is), but they still work fine on already-correct numbering.
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    require("cascade").renumber()
    eq_lines(
      vim.api.nvim_buf_get_lines(b, 0, -1, false),
      { "1. two", "2. one", "3. three" },
      "manual renumber leaves correct numbering alone"
    )
    vim.api.nvim_exec_autocmds("BufWritePre", { buffer = b })
    eq_lines(vim.api.nvim_buf_get_lines(b, 0, -1, false), { "1. two", "2. one", "3. three" }, "and so does the on-save renumber")

    -- The contrast that used to localize the defect: the reordering
    -- transforms already kept the block anchored at 1.
    vim.api.nvim_buf_set_lines(b, 0, -1, false, { "1. c", "2. a", "3. b" })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    require("cascade").sort()
    eq_lines(vim.api.nvim_buf_get_lines(b, 0, -1, false), { "1. a", "2. b", "3. c" }, "sort: reorders without drifting the start")
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    require("cascade").reverse()
    eq_lines(vim.api.nvim_buf_get_lines(b, 0, -1, false), { "1. c", "2. b", "3. a" }, "reverse: likewise")

    -- And the behaviour the anchoring exists for, which a naive fix would
    -- break: a list deliberately starting at 5 must keep starting at 5.
    vim.api.nvim_buf_set_lines(b, 0, -1, false, { "5. five", "6. six", "7. seven" })
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    move.selection(b, 1, 1, 1, opts)
    eq_lines(
      vim.api.nvim_buf_get_lines(b, 0, -1, false),
      { "5. five", "6. seven", "7. six" },
      "move: a non-1 start is preserved when the first item does not move"
    )
  end

  do
    -- A non-list selection moves without any renumber attempt.
    cfg.setup({})
    local opts = cfg.get("lists")
    local b = H.editable("markdown")
    vim.api.nvim_buf_set_lines(b, 0, -1, false, { "prose one", "prose two", "prose three" })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    ok(move.selection(b, 0, 0, 1, opts), "move.selection: a non-list line moves too")
    eq_lines(
      vim.api.nvim_buf_get_lines(b, 0, -1, false),
      { "prose two", "prose one", "prose three" },
      "move.selection: ... and lands where expected"
    )
  end

  -- ---------- checkbox: a state outside the configured cycle ----------

  do
    cfg.setup({ lists = { checkbox = { states = { " ", "x" } } } })
    local opts = cfg.get("lists")
    local b = H.editable("markdown")

    -- `[-]` is a perfectly valid single-character checkbox that another tool
    -- may have written, but it is not in `states`. It must re-enter the cycle
    -- at the first state rather than being left stuck.
    vim.api.nvim_buf_set_lines(b, 0, -1, false, { "- [-] partial" })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    ok(checkbox.toggle(Context.new(b), opts), "checkbox.toggle: an unknown state is handled")
    eq_lines(
      vim.api.nvim_buf_get_lines(b, 0, -1, false),
      { "- [ ] partial" },
      "checkbox.toggle: an unknown state re-enters the cycle at the first state"
    )

    -- From there the cycle is the ordinary one.
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    checkbox.toggle(Context.new(b), opts)
    eq_lines(vim.api.nvim_buf_get_lines(b, 0, -1, false), { "- [x] partial" }, "checkbox.toggle: then advances normally")
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    checkbox.toggle(Context.new(b), opts)
    eq_lines(vim.api.nvim_buf_get_lines(b, 0, -1, false), { "- [ ] partial" }, "checkbox.toggle: and wraps")

    -- An empty `states` list refuses rather than erroring on `states[1]`.
    cfg.setup({ lists = { checkbox = { states = {} } } })
    vim.api.nvim_buf_set_lines(b, 0, -1, false, { "- plain" })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    ok(not checkbox.toggle(Context.new(b), cfg.get("lists")), "checkbox.toggle: an empty states list refuses")
    eq_lines(vim.api.nvim_buf_get_lines(b, 0, -1, false), { "- plain" }, "checkbox.toggle: ... and leaves the line alone")

    -- A non-list line is refused before any state lookup.
    cfg.setup({})
    vim.api.nvim_buf_set_lines(b, 0, -1, false, { "just prose" })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    ok(not checkbox.toggle(Context.new(b), cfg.get("lists")), "checkbox.toggle: a non-list line refuses")
  end

  cfg.setup({})
end

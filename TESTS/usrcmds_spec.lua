-- TESTS/usrcmds_spec.lua — every `:Cascade` route, driven as a real Ex command.
--
-- `commands_spec` checks that the routes *exist* and complete; this file runs
-- them. The distinction matters because each route is a small adapter with its
-- own argument handling -- a range, a bang, an enum, an optional INT -- and an
-- adapter that quietly passes the wrong direction or drops a range looks
-- identical from the completion list.
--
-- Driven through `vim.cmd` rather than by calling the facade, so the composer's
-- own argument typing (`ctx.bang`, `ctx.args`, `ctx.rest`, `ctx.raw`) is part
-- of what is under test.

return function(H)
  local eq = H.eq
  local ok = H.ok
  local eq_lines = H.eq_lines

  local cfg = require("cascade.config")
  local cascade = require("cascade")

  cascade.setup({})
  ok(vim.fn.exists(":Cascade") == 2, "fixture: the :Cascade verb is defined")

  --- Fresh editable markdown buffer preloaded with `lines`, made current.
  ---@param lines string[]
  ---@return integer bufnr
  local function buf_with(lines)
    local b = H.editable("markdown")
    vim.api.nvim_buf_set_lines(b, 0, -1, false, lines)
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    return b
  end

  ---@param b integer
  ---@return string[]
  local function lines_of(b)
    return vim.api.nvim_buf_get_lines(b, 0, -1, false)
  end

  --- Run an Ex command, failing the spec with its own error text.
  ---@param command string
  ---@return nil
  local function ex(command)
    local got, err = pcall(vim.cmd, command)
    if not got then
      error(("FAIL %q raised: %s"):format(command, tostring(err)), 2)
    end
  end

  --- Run an Ex command, swallowing (and returning) whatever it notified.
  ---@param command string
  ---@return string[]
  local function ex_quiet(command)
    local seen = {}
    local orig = vim.notify
    -- Test double over a typed surface; restored right after the call.
    ---@diagnostic disable-next-line: duplicate-set-field
    vim.notify = function(msg)
      seen[#seen + 1] = tostring(msg)
    end
    local got, err = pcall(vim.cmd, command)
    vim.notify = orig
    if not got then
      error(("FAIL %q raised: %s"):format(command, tostring(err)), 2)
    end
    return seen
  end

  -- ---------- sort ----------

  do
    local b = buf_with({ "- c", "- a", "- b" })
    ex("Cascade sort")
    eq_lines(lines_of(b), { "- a", "- b", "- c" }, ":Cascade sort: A-Z on the cursor block")

    -- The bang belongs to the verb, not the subcommand: the composer parses
    -- `:Cascade! sort`, and `:Cascade sort!` is an unknown subcommand.
    ex("Cascade! sort")
    eq_lines(lines_of(b), { "- c", "- b", "- a" }, ":Cascade! sort: Z-A")

    -- An explicit range wins over the cursor block.
    vim.api.nvim_buf_set_lines(b, 0, -1, false, { "- z", "- c", "- a", "- b" })
    ex("2,4Cascade sort")
    eq_lines(lines_of(b), { "- z", "- a", "- b", "- c" }, ":Cascade sort with a range: only those lines")
  end

  -- ---------- reverse ----------

  do
    local b = buf_with({ "- a", "- b", "- c" })
    ex("Cascade reverse")
    eq_lines(lines_of(b), { "- c", "- b", "- a" }, ":Cascade reverse: the cursor block")

    vim.api.nvim_buf_set_lines(b, 0, -1, false, { "- a", "- b", "- c", "- d" })
    ex("1,2Cascade reverse")
    eq_lines(lines_of(b), { "- b", "- a", "- c", "- d" }, ":Cascade reverse with a range")
  end

  -- ---------- strip ----------

  do
    local b = buf_with({ "- [x] a", "- [ ] b" })
    ex("Cascade strip")
    eq_lines(lines_of(b), { "- a", "- b" }, ":Cascade strip: checkboxes removed")

    vim.api.nvim_buf_set_lines(b, 0, -1, false, { "- [x] a", "- [ ] b" })
    ex("1Cascade strip")
    eq_lines(lines_of(b), { "- a", "- [ ] b" }, ":Cascade strip with a single-line range")
  end

  -- ---------- rotate ----------

  do
    cfg.setup({ lists = { forms = { "-", "1." } } })
    local b = buf_with({ "- a", "- b" })
    ex("Cascade rotate")
    eq_lines(lines_of(b), { "1. a", "2. b" }, ":Cascade rotate: forward through lists.forms")

    -- Both the bang and the explicit "prev" argument mean backward, and they
    -- must agree.
    ex("Cascade! rotate")
    eq_lines(lines_of(b), { "- a", "- b" }, ":Cascade! rotate: backward")

    ex("Cascade rotate next")
    eq_lines(lines_of(b), { "1. a", "2. b" }, ":Cascade rotate next: forward, explicitly")

    ex("Cascade rotate prev")
    eq_lines(lines_of(b), { "- a", "- b" }, ":Cascade rotate prev: backward, explicitly")

    -- ! and "next" together: the bang wins (it is checked with `or`).
    ex("Cascade rotate")
    ex("Cascade! rotate next")
    eq_lines(lines_of(b), { "- a", "- b" }, ":Cascade! rotate next: the bang wins over the argument")

    cfg.setup({})
  end

  -- ---------- indent / dedent ----------

  do
    local b = buf_with({ "- a", "- b" })
    vim.bo[b].expandtab = true
    vim.bo[b].shiftwidth = 2

    ex("1,2Cascade indent")
    eq_lines(lines_of(b), { "  - a", "  - b" }, ":Cascade indent with a range")
    ex("1,2Cascade dedent")
    eq_lines(lines_of(b), { "- a", "- b" }, ":Cascade dedent with a range")

    -- BUG: the optional INT argument is documented as a level count ("arg =
    -- levels" in the route's own desc, and the route declares
    -- `{ name = "levels", type = "INT" }`) but it is silently ignored -- every
    -- `:Cascade indent N` shifts by exactly one level.
    --
    -- The route hands `ctx.raw` to `api.run_indent_command`, which reads
    -- `tonumber(cmd.args)`. Under the composer `cmd.args` is the WHOLE tail,
    -- subcommand included: for `:Cascade indent 3` it is the string
    -- "indent 3", so `tonumber` returns nil and the count degrades to 1. The
    -- correctly typed value is sitting in `ctx.args.levels` (verified: the
    -- composer does parse it) and is thrown away. The keymap path
    -- (`<leader><A-Right>` with a count) is unaffected -- it reads
    -- `vim.v.count1` -- so the defect is specific to the Ex command, which is
    -- exactly where the argument is advertised.
    --
    -- Pinned rather than fixed: the repair is one line in
    -- `bindings/usrcmds.lua` (pass `ctx.args.levels` through instead of
    -- letting `run_indent_command` re-parse the raw tail), but it changes what
    -- an existing `:Cascade indent 3` does.
    ex("1,2Cascade indent 3")
    eq_lines(lines_of(b), { "  - a", "  - b" }, "BUG: :Cascade indent 3 shifts one level, not three")
    ex("1,2Cascade dedent 3")
    eq_lines(lines_of(b), { "- a", "- b" }, "BUG: :Cascade dedent 3 likewise shifts one level")

    -- The same count *does* work through the keymap surface, which is what
    -- makes this a command-layer defect rather than an indent one.
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    vim.keymap.set("n", "<F13>", cascade.indent_levels)
    vim.api.nvim_feedkeys(vim.keycode("3<F13>"), "mtx", false)
    vim.keymap.del("n", "<F13>")
    eq_lines(lines_of(b), { "      - a", "- b" }, "indent_levels: a count on the KEY does shift three levels")
    ex("1Cascade dedent 3")
    ex("1Cascade dedent 3")
    ex("1Cascade dedent 3")
    eq_lines(lines_of(b), { "- a", "- b" }, "fixture: back to one level via three single-level dedents")

    -- No range: the cursor line only.
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    ex("Cascade indent")
    eq_lines(lines_of(b), { "- a", "  - b" }, ":Cascade indent without a range: the cursor line")
    ex("Cascade dedent")
    eq_lines(lines_of(b), { "- a", "- b" }, ":Cascade dedent without a range")
  end

  -- ---------- renumber ----------

  do
    local b = buf_with({ "1. a", "1. b", "1. c" })
    ex("Cascade renumber")
    eq_lines(lines_of(b), { "1. a", "2. b", "3. c" }, ":Cascade renumber: the cursor block")

    vim.api.nvim_buf_set_lines(b, 0, -1, false, { "1. a", "1. b", "", "7. x", "7. y" })
    ex("Cascade renumber all")
    eq_lines(lines_of(b), { "1. a", "2. b", "", "7. x", "8. y" }, ":Cascade renumber all: every block in the buffer")

    -- The `selection` scope goes to the sequence domain, which reads the
    -- numbers *inside* the lines and works in any filetype.
    vim.api.nvim_buf_set_lines(b, 0, -1, false, { "## 3. drei", "## 9. neun", "## 1. eins" })
    ex("1,3Cascade renumber selection")
    eq_lines(
      lines_of(b),
      { "## 3. drei", "## 4. neun", "## 5. eins" },
      ":Cascade renumber selection: one sequence across the range"
    )

    -- A range plus the default scope stays in the list domain.
    vim.api.nvim_buf_set_lines(b, 0, -1, false, { "1. a", "1. b", "1. c" })
    ex("1,2Cascade renumber")
    eq_lines(lines_of(b), { "1. a", "2. b", "1. c" }, ":Cascade renumber with a range: only those lines")
  end

  -- ---------- cycle list / add / remove ----------

  do
    cfg.setup({ cycle = { packs = {}, groups = { { "on", "off" } } } })
    local msgs = ex_quiet("Cascade cycle list")
    local joined = table.concat(msgs, "\n")
    ok(joined:find("on -> off", 1, true) ~= nil, ":Cascade cycle list: reports the configured group")

    -- A group whose values contain spaces: the route takes the whole tail, not
    -- just the first token, or everything after the first space is dropped.
    ex_quiet("Cascade cycle add TODO,IN PROGRESS,DONE")
    local groups = cfg.get("cycle").groups
    eq_lines(groups[#groups], { "TODO", "IN PROGRESS", "DONE" }, ":Cascade cycle add: the whole tail is taken, spaces and all")

    -- BUG (the mirror of the line above): `cycle remove`'s route reads only
    -- `ctx.args.value` and, unlike `cycle add`, never appends `ctx.rest` -- so
    -- a value containing a space arrives truncated at the first token and
    -- matches nothing. A group added as "TODO,IN PROGRESS,DONE" therefore
    -- cannot be removed by the member that made `cycle add` need the tail in
    -- the first place.
    --
    -- Pinned rather than fixed: the repair is the same three lines `cycle add`
    -- already carries, but it makes a command that currently reports "no group
    -- contains ..." start succeeding.
    local truncated = ex_quiet("Cascade cycle remove IN PROGRESS")
    eq(#cfg.get("cycle").groups, 2, "BUG: :Cascade cycle remove drops everything after the first word")
    ok(
      table.concat(truncated, "\n"):find("no group contains", 1, true) ~= nil,
      "BUG: ... and reports the truncated value as unknown"
    )

    -- A single-word member of the same group does remove it, which is the
    -- workaround and the proof that only the argument handling is at fault.
    ex_quiet("Cascade cycle remove TODO")
    eq(#cfg.get("cycle").groups, 1, ":Cascade cycle remove: a single-word member removes the group")

    -- A single-token group still works (the `rest` branch is simply empty).
    ex_quiet("Cascade cycle add alpha,beta")
    local g2 = cfg.get("cycle").groups
    eq_lines(g2[#g2], { "alpha", "beta" }, ":Cascade cycle add: the no-tail case")
    ex_quiet("Cascade cycle remove alpha")

    -- A refusal is a notification, not an error out of the command.
    local refused = ex_quiet("Cascade cycle add onlyone")
    ok(
      table.concat(refused, "\n"):find("at least two distinct", 1, true) ~= nil,
      ":Cascade cycle add: a refusal is reported, not raised"
    )

    local missing = ex_quiet("Cascade cycle remove nothing-holds-this")
    ok(
      table.concat(missing, "\n"):find("no group contains", 1, true) ~= nil,
      ":Cascade cycle remove: an unknown value is reported"
    )

    cfg.setup({})
  end

  -- ---------- completion ----------

  do
    local subs = vim.fn.getcompletion("Cascade ", "cmdline")
    for _, want in ipairs({ "cycle", "rotate", "sort", "reverse", "strip", "indent", "dedent", "renumber" }) do
      ok(vim.tbl_contains(subs, want), (":Cascade completion offers %q"):format(want))
    end

    local cyc = vim.fn.getcompletion("Cascade cycle ", "cmdline")
    for _, want in ipairs({ "list", "add", "remove" }) do
      ok(vim.tbl_contains(cyc, want), (":Cascade cycle completion offers %q"):format(want))
    end

    -- The enum arguments complete their own values.
    local dirs = vim.fn.getcompletion("Cascade rotate ", "cmdline")
    ok(vim.tbl_contains(dirs, "next") and vim.tbl_contains(dirs, "prev"), ":Cascade rotate completes next/prev")

    local scopes = vim.fn.getcompletion("Cascade renumber ", "cmdline")
    ok(vim.tbl_contains(scopes, "all") and vim.tbl_contains(scopes, "selection"), ":Cascade renumber completes all/selection")
  end

  -- ---------- the commands respect the domain switches ----------

  do
    cfg.setup({ lists = { enable = false } })
    local b = buf_with({ "- c", "- a" })
    ex("1,2Cascade sort")
    ex("1,2Cascade reverse")
    ex("Cascade renumber all")
    eq_lines(lines_of(b), { "- c", "- a" }, ":Cascade transforms: refused with lists disabled")

    cfg.setup({})
    ex("1,2Cascade sort")
    eq_lines(lines_of(b), { "- a", "- c" }, ":Cascade sort: works again once lists are enabled")
  end

  do
    -- A non-writable buffer is refused by the command layer, not just by the
    -- keymaps.
    cfg.setup({})
    local b = H.scratch("markdown")
    vim.api.nvim_buf_set_lines(b, 0, -1, false, { "- c", "- a" })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    ex("1,2Cascade sort")
    ex("1,2Cascade indent")
    ex("Cascade renumber all")
    eq_lines(lines_of(b), { "- c", "- a" }, ":Cascade: a non-writable buffer is refused")
  end

  cascade.setup({})
end

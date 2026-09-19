-- TESTS/facade_spec.lua — the parts of `cascade/init.lua` the other specs
-- reach only through a keymap, if at all.
--
-- `commands_spec` drives the facade through real keypresses, which is the
-- right test for the wiring but a poor one for the gates: a feature switch
-- that silently stops working looks exactly like a keymap that was never
-- bound. This file calls the facade functions directly instead, so each gate
-- (`lists.enable`, the per-feature flags, `writable()`, the filetype list) is
-- asserted as its own decision, and the `:command` entry points
-- (`run_command`, `run_indent_command`, `run_renumber_command`) are driven
-- with hand-built argument tables rather than through the composer.

return function(H)
  local eq = H.eq
  local ok = H.ok
  local eq_lines = H.eq_lines

  local cfg = require("cascade.config")
  local cascade = require("cascade")

  --- Fresh editable buffer preloaded with `lines`, made current.
  ---@param lines string[]
  ---@param ft string|nil
  ---@return integer bufnr
  local function buf_with(lines, ft)
    local b = H.editable(ft or "markdown")
    vim.api.nvim_buf_set_lines(b, 0, -1, false, lines)
    return b
  end

  ---@param b integer
  ---@return string[]
  local function lines_of(b)
    return vim.api.nvim_buf_get_lines(b, 0, -1, false)
  end

  --- Collect the messages the facade notifies while `fn` runs.
  ---@param fn fun()
  ---@return string[]
  local function notices(fn)
    local seen = {}
    local orig = vim.notify
    -- Test double over a typed surface; restored right after the call.
    ---@diagnostic disable-next-line: duplicate-set-field
    vim.notify = function(msg)
      seen[#seen + 1] = tostring(msg)
    end
    local called_ok, err = pcall(fn)
    vim.notify = orig
    if not called_ok then
      error(err, 2)
    end
    return seen
  end

  --- Whether any of `msgs` contains `needle`.
  ---@param msgs string[]
  ---@param needle string
  ---@return boolean
  local function said(msgs, needle)
    for i = 1, #msgs do
      if msgs[i]:find(needle, 1, true) then
        return true
      end
    end
    return false
  end

  -- ---------- runtime cycle groups ----------

  do
    cfg.setup({ cycle = { packs = {}, groups = { { "on", "off" } } } })

    local msgs = notices(function()
      ok(cascade.cycle_group_add("alpha, beta , gamma"), "cycle_group_add: three values accepted")
    end)
    ok(said(msgs, "alpha -> beta -> gamma"), "cycle_group_add: reports what it added, trimmed")
    eq(#cfg.get("cycle").groups, 2, "cycle_group_add: appended to the live groups")

    -- Fewer than two *distinct* values makes the cycle a no-op, so both the
    -- too-short and the all-duplicates form are refused.
    msgs = notices(function()
      ok(not cascade.cycle_group_add("only"), "cycle_group_add: a single value is refused")
      ok(not cascade.cycle_group_add("same,same,same"), "cycle_group_add: duplicates collapse and are refused")
      ok(not cascade.cycle_group_add(""), "cycle_group_add: an empty string is refused")
      ok(not cascade.cycle_group_add(nil), "cycle_group_add: nil is refused")
    end)
    ok(said(msgs, "at least two distinct"), "cycle_group_add: says why it refused")
    eq(#cfg.get("cycle").groups, 2, "cycle_group_add: a refusal appends nothing")

    -- Duplicates *within* an otherwise valid group are dropped, not kept.
    notices(function()
      ok(cascade.cycle_group_add("red,green,red,blue"), "cycle_group_add: partial duplicates are fine")
    end)
    local added = cfg.get("cycle").groups[3]
    eq_lines(added, { "red", "green", "blue" }, "cycle_group_add: the repeat was dropped")

    msgs = notices(function()
      ok(cascade.cycle_group_remove("green"), "cycle_group_remove: removes by any member")
    end)
    ok(said(msgs, "red -> green -> blue"), "cycle_group_remove: reports what it removed")
    eq(#cfg.get("cycle").groups, 2, "cycle_group_remove: the group is gone")

    msgs = notices(function()
      ok(not cascade.cycle_group_remove("nothing-holds-this"), "cycle_group_remove: an unknown value is refused")
      ok(not cascade.cycle_group_remove(""), "cycle_group_remove: an empty value is refused")
      ok(not cascade.cycle_group_remove(nil), "cycle_group_remove: nil is refused")
    end)
    ok(said(msgs, "no group contains"), "cycle_group_remove: says why it refused")

    -- Removal takes the LAST matching group, so a runtime group added over a
    -- configured one is what goes first.
    cfg.setup({ cycle = { packs = {}, groups = { { "a", "b" } } } })
    notices(function()
      cascade.cycle_group_add("a,z")
    end)
    notices(function()
      cascade.cycle_group_remove("a")
    end)
    eq(#cfg.get("cycle").groups, 1, "cycle_group_remove: one group at a time")
    eq_lines(cfg.get("cycle").groups[1], { "a", "b" }, "cycle_group_remove: the runtime addition goes before the configured one")
  end

  do
    cfg.setup({ cycle = { packs = {}, groups = { { "on", "off" }, { "up", "down" } } } })
    local b = buf_with({ "x = on" }, "lua")

    local msgs = notices(function()
      cascade.cycle_groups_list()
    end)
    ok(said(msgs, "cycle groups in effect for lua"), "cycle_groups_list: names the filetype")
    ok(said(msgs, "on -> off"), "cycle_groups_list: lists the global groups")
    ok(said(msgs, "up -> down"), "cycle_groups_list: lists all of them")

    -- Per-filetype groups are listed too, labelled as such -- reading only
    -- `groups` would answer the wrong question for this buffer.
    cfg.setup({
      cycle = { packs = {}, groups = { { "on", "off" } }, per_filetype = { lua = { { "nil", "false" } } } },
    })
    msgs = notices(function()
      cascade.cycle_groups_list()
    end)
    ok(said(msgs, "nil -> false"), "cycle_groups_list: includes the per-filetype groups")
    ok(said(msgs, "(lua only)"), "cycle_groups_list: labels them as filetype-scoped")

    -- A buffer with no filetype still gets a readable header.
    vim.bo[b].filetype = ""
    msgs = notices(function()
      cascade.cycle_groups_list()
    end)
    ok(said(msgs, "<no filetype>"), "cycle_groups_list: unnamed filetype is spelled out")

    cfg.setup({ cycle = { packs = {}, groups = {} } })
    msgs = notices(function()
      cascade.cycle_groups_list()
    end)
    ok(said(msgs, "no cycle groups configured"), "cycle_groups_list: says so when there are none")
  end

  -- ---------- BUG: the runtime groups reach into config.DEFAULTS ----------

  do
    -- `lib.lua.config.deep_merge` copies only the TOP level of `base`, so any
    -- key the user did not override is the very table that lives in
    -- `cascade.config.DEFAULTS` -- including `cycle.groups`. The runtime
    -- group commands then append to (and remove from) the shipped defaults
    -- in place, which DEFAULTS' own module header forbids ("Never mutate it
    -- at runtime").
    --
    -- Two user-visible consequences, both asserted below:
    --   * `:Cascade cycle add` is documented as "deliberately not persisted",
    --     but it survives a fresh `setup()` -- a config reload no longer
    --     resets cascade to what the config file says.
    --   * `:Cascade cycle remove` deletes a SHIPPED group for the rest of the
    --     session, and no amount of re-`setup()` brings it back. Only
    --     restarting Neovim does.
    --
    -- Pinned rather than fixed: the repair belongs in `config.setup` (deep-
    -- copying what it hands out) or in these two functions (copying before
    -- mutating), and either one changes what `config.get()` returns for every
    -- caller in the plugin -- deliberately a separate change.
    local DEFAULTS = require("cascade.config.DEFAULTS")
    local shipped = #DEFAULTS.cycle.groups

    cfg.setup({})
    ok(cfg.get("cycle").groups == DEFAULTS.cycle.groups, "BUG: config.get() hands out the DEFAULTS table itself")

    notices(function()
      cascade.cycle_group_add("pin-a,pin-b")
    end)
    eq(#DEFAULTS.cycle.groups, shipped + 1, "BUG: cycle_group_add grew config.DEFAULTS in place")

    cfg.setup({}) -- a full re-setup, as a config reload would do
    local survived = false
    for _, g in ipairs(cfg.get("cycle").groups) do
      if g[1] == "pin-a" then
        survived = true
      end
    end
    ok(survived, "BUG: the runtime group outlives a fresh setup()")

    notices(function()
      cascade.cycle_group_remove("pin-a") -- clean up our own addition
    end)
    eq(#DEFAULTS.cycle.groups, shipped, "DEFAULTS is back to its shipped size")

    -- Removing a shipped group is likewise permanent.
    notices(function()
      cascade.cycle_group_remove("==")
    end)
    cfg.setup({})
    local has_operator_group = false
    for _, g in ipairs(cfg.get("cycle").groups) do
      if g[1] == "==" then
        has_operator_group = true
      end
    end
    ok(not has_operator_group, "BUG: a removed shipped group does not come back on setup()")

    -- Restore the shipped group so the rest of the suite sees a stock config.
    table.insert(DEFAULTS.cycle.groups, 2, { "==", "!=" })
    cfg.setup({})
    eq_lines(cfg.get("cycle").groups[2], { "==", "!=" }, "fixture: the shipped operator group is restored")
    eq(#DEFAULTS.cycle.groups, shipped, "fixture: DEFAULTS is whole again")

    -- A user who supplies their own `cycle.groups` gets their own array
    -- (list-like values are replaced wholesale), so DEFAULTS is untouched --
    -- their table is mutated instead, which is the milder half of the same
    -- defect.
    local mine = { { "one", "two" } }
    cfg.setup({ cycle = { groups = mine } })
    ok(cfg.get("cycle").groups == mine, "BUG: a user-supplied groups array is handed back by reference too")
    notices(function()
      cascade.cycle_group_add("three,four")
    end)
    eq(#mine, 2, "BUG: ... and the caller's own table is grown behind their back")
  end

  -- ---------- gates: lists ----------

  do
    cfg.setup({ lists = { enable = false } })
    local b = buf_with({ "- one", "- two" })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    cascade.toggle_checkbox()
    cascade.cycle_type_next()
    cascade.bullet_toggle()
    cascade.renumber()
    eq_lines(lines_of(b), { "- one", "- two" }, "lists.enable = false: every list action is a no-op")
  end

  do
    -- A buffer whose filetype is not configured is out of scope, even with
    -- lists enabled.
    cfg.setup({})
    local b = buf_with({ "- one" }, "lua")
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    cascade.toggle_checkbox()
    eq_lines(lines_of(b), { "- one" }, "lists.filetypes: an unconfigured filetype is untouched")

    vim.bo[b].filetype = "markdown"
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    cascade.toggle_checkbox()
    eq_lines(lines_of(b), { "- [ ] one" }, "lists.filetypes: ... and a configured one is not")
  end

  do
    -- A non-writable buffer is refused even in a configured filetype: the
    -- scratch helper is `buftype=nofile`, which `Context.writable` rejects.
    cfg.setup({})
    local b = H.scratch("markdown")
    vim.api.nvim_buf_set_lines(b, 0, -1, false, { "- one" })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    cascade.toggle_checkbox()
    eq_lines(lines_of(b), { "- one" }, "writable(): a scratch buffer is refused")

    vim.bo[b].modifiable = false
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    cascade.bullet_toggle()
    eq_lines(lines_of(b), { "- one" }, "writable(): a non-modifiable buffer is refused")
    vim.bo[b].modifiable = true
  end

  do
    -- Each list feature switch gates exactly its own action.
    local cases = {
      { feature = "checkbox", act = cascade.toggle_checkbox, line = "- one" },
      { feature = "cycle_type", act = cascade.cycle_type_next, line = "- one" },
      { feature = "bullet_toggle", act = cascade.bullet_toggle, line = "plain" },
      { feature = "number_toggle", act = cascade.number_toggle, line = "plain" },
      { feature = "checkbox_toggle", act = cascade.checkbox_toggle, line = "plain" },
      { feature = "sort", act = cascade.sort, line = "- b" },
      { feature = "reverse", act = cascade.reverse, line = "- b" },
      { feature = "rotate", act = cascade.rotate_form_next, line = "- b" },
      { feature = "strip", act = cascade.strip_checkbox, line = "- [x] b" },
    }
    for _, case in ipairs(cases) do
      cfg.setup({ lists = { features = { [case.feature] = false } } })
      local b = buf_with({ case.line })
      vim.api.nvim_win_set_cursor(0, { 1, 0 })
      case.act()
      eq_lines(lines_of(b), { case.line }, ("lists.features.%s = false: the action is a no-op"):format(case.feature))
    end
  end

  do
    -- move has its own switch, checked before the buffer is touched.
    cfg.setup({ lists = { features = { move = false } } })
    local b = buf_with({ "one", "two" })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    cascade.move_down()
    eq_lines(lines_of(b), { "one", "two" }, "lists.features.move = false: move_down is a no-op")

    cfg.setup({})
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    cascade.move_down()
    eq_lines(lines_of(b), { "two", "one" }, "move_down: swaps with the next line")
    cascade.move_up()
    eq_lines(lines_of(b), { "one", "two" }, "move_up: and back")

    -- At the buffer edge it stops rather than erroring.
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    cascade.move_up()
    eq_lines(lines_of(b), { "one", "two" }, "move_up: refuses at the first line")
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    cascade.move_down()
    eq_lines(lines_of(b), { "one", "two" }, "move_down: refuses at the last line")
  end

  -- ---------- gates: cycle / transpose ----------

  do
    cfg.setup({ cycle = { enable = false, packs = { "en" } } })
    local b = buf_with({ "flag = yes" }, "lua")
    vim.api.nvim_win_set_cursor(0, { 1, 7 })
    cascade.cycle_word_next()
    cascade.cycle_char_next()
    cascade.cycle_pick()
    eq_lines(lines_of(b), { "flag = yes" }, "cycle.enable = false: nothing cycles")

    cfg.setup({ cycle = { packs = { "en" }, features = { word = false } } })
    vim.api.nvim_win_set_cursor(0, { 1, 7 })
    cascade.cycle_word_next()
    eq_lines(lines_of(b), { "flag = yes" }, "cycle.features.word = false: the word does not cycle")

    cfg.setup({ cycle = { packs = { "en" }, features = { char = false } } })
    vim.api.nvim_win_set_cursor(0, { 1, 7 })
    cascade.cycle_char_next()
    eq_lines(lines_of(b), { "flag = yes" }, "cycle.features.char = false: the char does not cycle")

    -- cycle.filetypes narrows the domain, which is otherwise global.
    cfg.setup({ cycle = { packs = { "en" }, filetypes = { "markdown" } } })
    vim.api.nvim_win_set_cursor(0, { 1, 7 })
    cascade.cycle_word_next()
    eq_lines(lines_of(b), { "flag = yes" }, "cycle.filetypes: a lua buffer is out of scope")

    vim.bo[b].filetype = "markdown"
    vim.api.nvim_win_set_cursor(0, { 1, 7 })
    cascade.cycle_word_next()
    eq_lines(lines_of(b), { "flag = no" }, "cycle.filetypes: ... and a markdown one is in scope")
  end

  do
    cfg.setup({ transpose = { enable = false } })
    local b = buf_with({ "ab cd" }, "lua")
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    cascade.swap_right()
    cascade.swap_word_right()
    eq_lines(lines_of(b), { "ab cd" }, "transpose.enable = false: nothing swaps")

    cfg.setup({ transpose = { features = { char = false } } })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    cascade.swap_right()
    eq_lines(lines_of(b), { "ab cd" }, "transpose.features.char = false: chars do not swap")

    cfg.setup({ transpose = { features = { word = false } } })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    cascade.swap_word_right()
    eq_lines(lines_of(b), { "ab cd" }, "transpose.features.word = false: words do not swap")

    cfg.setup({})
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    cascade.swap_right()
    eq_lines(lines_of(b), { "ba cd" }, "transpose: enabled again, the char swaps")
  end

  -- ---------- cr / o / O and their fallbacks ----------

  --- Execute whatever the facade queued with `nvim_feedkeys` (its native-key
  --- fallbacks are queued, not immediate) and return to Normal mode, so the
  --- next case does not inherit a half-processed keypress.
  ---@return nil
  local function flush_pending()
    vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "x", false)
  end

  do
    cfg.setup({})
    -- `cr_literal` never continues a list, whatever the cursor is on: it
    -- feeds a native <CR>, which in Normal mode only moves the cursor.
    local b = buf_with({ "- one", "- two" })
    vim.api.nvim_win_set_cursor(0, { 1, 5 })
    cascade.cr_literal()
    flush_pending()
    eq_lines(lines_of(b), { "- one", "- two" }, "cr_literal: never inserts a continuation marker")
  end

  do
    -- The markdown.nvim table-row bridge: the plugin is not installed here,
    -- so the `pcall(require, ...)` arm is the live one and `o`/`O` must fall
    -- through to their native meaning rather than erroring or inventing a row.
    cfg.setup({})
    ok(not pcall(require, "markdown.core.table_mode"), "fixture: markdown.nvim is genuinely absent")
    local b = buf_with({ "| a | b |" })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    cascade.o()
    flush_pending()
    eq_lines(lines_of(b), { "| a | b |", "" }, "o: falls through to a native 'o' -- no table row invented")

    vim.api.nvim_buf_set_lines(b, 0, -1, false, { "| a | b |" })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    cascade.O()
    flush_pending()
    eq_lines(lines_of(b), { "", "| a | b |" }, "O: falls through to a native 'O'")

    -- On an actual list item the continuation wins and no native key is fed.
    vim.api.nvim_buf_set_lines(b, 0, -1, false, { "- one" })
    vim.api.nvim_win_set_cursor(0, { 1, 5 })
    cascade.o()
    flush_pending()
    eq_lines(lines_of(b), { "- one", "- " }, "o: on a list item the continuation marker is inserted")
  end

  -- ---------- the :command entry points ----------

  do
    cfg.setup({})
    local transform = cascade._transform
    ok(type(transform) == "table", "_transform: exposed for the command layer")

    local b = buf_with({ "- c", "- a", "- b" })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })

    -- With an explicit range, the range wins over the cursor block.
    cascade.run_command(transform.sort, { range = 2, line1 = 1, line2 = 3 }, 1)
    eq_lines(lines_of(b), { "- a", "- b", "- c" }, "run_command: an explicit range is used")

    -- Descending.
    cascade.run_command(transform.sort, { range = 2, line1 = 1, line2 = 3 }, -1)
    eq_lines(lines_of(b), { "- c", "- b", "- a" }, "run_command: dir = -1 sorts Z-A")

    -- Without a range it resolves the block at the cursor.
    cascade.run_command(transform.sort, { range = 0 }, 1)
    eq_lines(lines_of(b), { "- a", "- b", "- c" }, "run_command: no range falls back to the cursor block")

    cascade.run_command(transform.reverse, { range = 0 }, 1)
    eq_lines(lines_of(b), { "- c", "- b", "- a" }, "run_command: reverse")

    -- Gated on lists.enable like everything else.
    cfg.setup({ lists = { enable = false } })
    cascade.run_command(transform.sort, { range = 2, line1 = 1, line2 = 3 }, 1)
    eq_lines(lines_of(b), { "- c", "- b", "- a" }, "run_command: refuses when lists are disabled")
    cfg.setup({})
  end

  do
    cfg.setup({})
    local b = buf_with({ "1. one", "1. two", "1. three" })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })

    cascade.run_renumber_command({ range = 0 }, nil)
    eq_lines(lines_of(b), { "1. one", "2. two", "3. three" }, "run_renumber_command: no scope renumbers the cursor block")

    vim.api.nvim_buf_set_lines(b, 0, -1, false, { "1. one", "", "5. far", "5. away" })
    cascade.run_renumber_command({ range = 0 }, "all")
    eq_lines(lines_of(b), { "1. one", "", "5. far", "6. away" }, "run_renumber_command: 'all' sweeps every block")

    -- 'selection' routes to the sequence domain, which is filetype-independent
    -- and reads the numbers *inside* the lines.
    vim.api.nvim_buf_set_lines(b, 0, -1, false, { "### 4. vier", "### 9. neun" })
    cascade.run_renumber_command({ range = 2, line1 = 1, line2 = 2 }, "selection")
    eq_lines(lines_of(b), { "### 4. vier", "### 5. neun" }, "run_renumber_command: 'selection' uses the sequence domain")

    -- ... and is gated on `sequence.enable`, separately from `lists.enable`.
    cfg.setup({ sequence = { enable = false } })
    vim.api.nvim_buf_set_lines(b, 0, -1, false, { "### 4. vier", "### 9. neun" })
    cascade.run_renumber_command({ range = 2, line1 = 1, line2 = 2 }, "selection")
    eq_lines(lines_of(b), { "### 4. vier", "### 9. neun" }, "run_renumber_command: 'selection' respects sequence.enable")

    -- Conversely, 'selection' keeps working with the LIST domain off -- the
    -- two switches are independent.
    cfg.setup({ lists = { enable = false } })
    vim.api.nvim_buf_set_lines(b, 0, -1, false, { "### 4. vier", "### 9. neun" })
    cascade.run_renumber_command({ range = 2, line1 = 1, line2 = 2 }, "selection")
    eq_lines(lines_of(b), { "### 4. vier", "### 5. neun" }, "run_renumber_command: 'selection' ignores lists.enable")

    -- ... while the block scopes do not.
    vim.api.nvim_buf_set_lines(b, 0, -1, false, { "1. one", "1. two" })
    cascade.run_renumber_command({ range = 0 }, nil)
    cascade.run_renumber_command({ range = 0 }, "all")
    eq_lines(lines_of(b), { "1. one", "1. two" }, "run_renumber_command: block scopes respect lists.enable")
    cfg.setup({})
  end

  do
    cfg.setup({})
    local b = buf_with({ "- one", "- two" })
    vim.bo[b].expandtab = true
    vim.bo[b].shiftwidth = 2
    vim.api.nvim_win_set_cursor(0, { 1, 0 })

    cascade.run_indent_command({ range = 2, line1 = 1, line2 = 2 }, 1)
    eq_lines(lines_of(b), { "  - one", "  - two" }, "run_indent_command: indents the whole range")

    cascade.run_indent_command({ range = 2, line1 = 1, line2 = 2 }, -1)
    eq_lines(lines_of(b), { "- one", "- two" }, "run_indent_command: and dedents it again")

    -- `levels` (the composer-parsed arg, not raw `cmd.args`) is a LEVEL count.
    cascade.run_indent_command({ range = 2, line1 = 1, line2 = 2 }, 1, 3)
    eq_lines(lines_of(b), { "      - one", "      - two" }, "run_indent_command: levels is a level count")
    cascade.run_indent_command({ range = 2, line1 = 1, line2 = 2 }, -1, 3)
    eq_lines(lines_of(b), { "- one", "- two" }, "run_indent_command: symmetric")

    -- A junk or non-positive levels value degrades to one level rather than
    -- erroring or shifting by zero.
    cascade.run_indent_command({ range = 2, line1 = 1, line2 = 2 }, 1, "not-a-number")
    eq_lines(lines_of(b), { "  - one", "  - two" }, "run_indent_command: a junk levels value means one level")
    cascade.run_indent_command({ range = 2, line1 = 1, line2 = 2 }, -1, 0)
    eq_lines(lines_of(b), { "- one", "- two" }, "run_indent_command: a zero levels value means one level")

    -- Without a range it addresses the cursor line only.
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    cascade.run_indent_command({ range = 0 }, 1)
    eq_lines(lines_of(b), { "- one", "  - two" }, "run_indent_command: no range means the cursor line")
    cascade.run_indent_command({ range = 0 }, -1)
    eq_lines(lines_of(b), { "- one", "- two" }, "run_indent_command: ... symmetrically")
  end

  do
    -- Every command entry point refuses a non-writable buffer before
    -- touching it.
    cfg.setup({})
    local b = H.scratch("markdown")
    vim.api.nvim_buf_set_lines(b, 0, -1, false, { "1. one", "1. two" })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    cascade.run_command(cascade._transform.sort, { range = 2, line1 = 1, line2 = 2 }, 1)
    cascade.run_renumber_command({ range = 0 }, "all")
    cascade.run_indent_command({ range = 0 }, 1)
    eq_lines(lines_of(b), { "1. one", "1. two" }, "commands: a non-writable buffer is refused by all three")
  end

  -- ---------- counts ----------

  --- Drive `action` through a throwaway normal-mode key with `count` typed in
  --- front of it, so `vim.v.count1` is genuinely the keypress's own (which is
  --- the only way the dot-repeat trampoline's stashed count can be tested).
  ---@param count integer|nil
  ---@param action fun()
  ---@return nil
  local function with_count(count, action)
    vim.keymap.set("n", "<F13>", action)
    vim.api.nvim_feedkeys(vim.keycode((count and tostring(count) or "") .. "<F13>"), "mtx", false)
    vim.keymap.del("n", "<F13>")
  end

  do
    cfg.setup({})
    -- `bullet_toggle`'s count widens the SCOPE (N lines) rather than
    -- repeating the toggle N times, which for an even count would be a no-op.
    local b = buf_with({ "one", "two", "three", "four" })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    with_count(3, cascade.bullet_toggle)
    eq_lines(lines_of(b), { "- one", "- two", "- three", "four" }, "3<bullet_toggle>: covers three lines, one level each")

    -- A count larger than the remaining lines stops at the last one instead
    -- of erroring.
    vim.api.nvim_buf_set_lines(b, 0, -1, false, { "one", "two" })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    with_count(99, cascade.bullet_toggle)
    eq_lines(lines_of(b), { "- one", "- two" }, "99<bullet_toggle>: clamps to the last line")

    -- No count is the single-line case.
    vim.api.nvim_buf_set_lines(b, 0, -1, false, { "one", "two" })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    with_count(nil, cascade.star_toggle)
    eq_lines(lines_of(b), { "* one", "two" }, "star_toggle with no count: the cursor line only")

    vim.api.nvim_buf_set_lines(b, 0, -1, false, { "one", "two", "three" })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    with_count(2, cascade.star_toggle)
    eq_lines(lines_of(b), { "* one", "* two", "three" }, "2<star_toggle>: covers two lines")
  end

  do
    -- The cycle count STEPS N times rather than jumping N places, so a
    -- three-state group wraps correctly.
    cfg.setup({ cycle = { packs = {}, groups = { { "one", "two", "three" } } } })
    local b = buf_with({ "one" }, "lua")
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    with_count(2, cascade.cycle_word_next)
    eq_lines(lines_of(b), { "three" }, "2<cycle_word_next>: two steps forward")

    vim.api.nvim_buf_set_lines(b, 0, -1, false, { "one" })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    with_count(4, cascade.cycle_word_next)
    eq_lines(lines_of(b), { "two" }, "4<cycle_word_next>: wraps past the end of a 3-state group")

    vim.api.nvim_buf_set_lines(b, 0, -1, false, { "one" })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    with_count(2, cascade.cycle_word_prev)
    eq_lines(lines_of(b), { "two" }, "2<cycle_word_prev>: two steps backward, wrapping")
  end

  do
    -- `_move`'s count moves one line at a time N times (so the reindent and
    -- renumber stay correct at every step) and stops at the buffer edge.
    cfg.setup({})
    local b = buf_with({ "a", "b", "c", "d" })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    with_count(2, cascade.move_down)
    eq_lines(lines_of(b), { "b", "c", "a", "d" }, "2<move_down>: two single-line moves")

    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    with_count(99, cascade.move_up)
    eq_lines(lines_of(b), { "b", "c", "a", "d" }, "99<move_up>: stops at the top instead of erroring")

    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    with_count(99, cascade.move_down)
    eq_lines(lines_of(b), { "c", "a", "d", "b" }, "99<move_down>: walks to the bottom and stops")
  end

  do
    -- The transpose count drags the character that many positions and stops
    -- early at the line boundary rather than erroring.
    cfg.setup({})
    local b = buf_with({ "abcd" }, "lua")
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    with_count(2, cascade.swap_right)
    eq_lines(lines_of(b), { "bcad" }, "2<swap_right>: dragged two positions right")

    vim.api.nvim_buf_set_lines(b, 0, -1, false, { "abcd" })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    with_count(99, cascade.swap_right)
    eq_lines(lines_of(b), { "bcda" }, "99<swap_right>: stops at the end of the line")

    vim.api.nvim_buf_set_lines(b, 0, -1, false, { "one two three" })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    with_count(2, cascade.swap_word_right)
    eq_lines(lines_of(b), { "two three one" }, "2<swap_word_right>: dragged past two words")
  end

  -- ---------- setup() ----------

  do
    -- setup() is cumulative over config but must not accumulate bindings; the
    -- autocmd side of that is asserted in bindings_spec. Here: a second
    -- setup() with a different config actually takes effect.
    cascade.setup({ lists = { checkbox = { states = { " ", "X" } } } })
    eq_lines(cfg.get("lists").checkbox.states, { " ", "X" }, "setup: the user's states are merged in")
    cascade.setup({ lists = { checkbox = { states = { " ", "y", "n" } } } })
    eq_lines(cfg.get("lists").checkbox.states, { " ", "y", "n" }, "setup: a re-setup replaces the list wholesale")

    -- setup(nil) is the documented "just take the defaults" call.
    cascade.setup(nil)
    eq_lines(cfg.get("lists").checkbox.states, { " ", "x", "~" }, "setup(nil): back to the shipped states")
    -- A non-table argument is treated the same rather than erroring.
    ---@diagnostic disable-next-line: param-type-mismatch
    cascade.setup("nonsense")
    eq(cfg.get("lists").enable, true, "setup: a non-table argument degrades to the defaults")
  end

  cfg.setup({})
end

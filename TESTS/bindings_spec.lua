-- TESTS/bindings_spec.lua — `cascade/bindings/{init,keymaps,autocmds}.lua`.
--
-- `commands_spec` proves the preset keys reach the right actions. What it
-- cannot see is the wiring's own contracts, which is what this file asserts:
--
--   * the three autocmds claim in their module doc to be idempotent ("their
--     augroups are cleared on every setup"). That claim has been wrong in
--     other repos of this fleet -- `lib.nvim`'s `autocmd.create` resolves a
--     *string* `group` through `M.group(name)` WITHOUT the clear argument, so
--     a caller that passes a name instead of a cleared group's id silently
--     accumulates a duplicate handler per `setup()`. cascade goes through
--     `util.lib.augroup`, which does clear -- pinned here by calling `setup()`
--     three times and counting.
--   * a switched-off feature must force its own keys off *on a copy*, so a
--     feature switch stays distinguishable from a per-key opt-out on the next
--     read of the live config.
--   * `keymaps.preset = false` binds no global keys but must still leave the
--     hanging-indent and save-renumber autocmds in place -- they are `lists`
--     behaviour, not keymap behaviour (a regression the suite already guards
--     for `format`; the save autocmd had no such guard).

return function(H)
  local eq = H.eq
  local ok = H.ok
  local eq_lines = H.eq_lines

  local cfg = require("cascade.config")
  local cascade = require("cascade")
  local keymaps = require("cascade.bindings.keymaps")

  --- How many autocmds live in `group` for `event`.
  ---@param group string
  ---@param event string
  ---@return integer
  local function autocmds(group, event)
    local got, res = pcall(vim.api.nvim_get_autocmds, { group = group, event = event })
    if not got then
      return 0 -- the augroup does not exist yet
    end
    return #res
  end

  --- The lhs list a registration result carries, as a set.
  ---@param registered table[]
  ---@return table<string, boolean>
  local function lhs_set(registered)
    local out = {}
    for i = 1, #registered do
      local entry = registered[i]
      local lhs = entry.lhs or entry[1]
      if type(lhs) == "string" then
        out[lhs] = true
      end
    end
    return out
  end

  -- ---------- autocmd idempotency ----------

  do
    cascade.setup({ keymaps = { preset = true } })
    local save1 = autocmds("cascade_renumber_save", "BufWritePre")
    local keys1 = autocmds("cascade_list_keymaps", "FileType")
    local fmt1 = autocmds("cascade_list_format", "FileType")

    eq(save1, 1, "autocmds: one BufWritePre renumber handler after setup")
    ok(keys1 > 0, "autocmds: the FileType keymap handler is registered")
    ok(fmt1 > 0, "autocmds: the FileType format handler is registered")

    cascade.setup({ keymaps = { preset = true } })
    cascade.setup({ keymaps = { preset = true } })

    eq(autocmds("cascade_renumber_save", "BufWritePre"), save1, "autocmds: three setups leave one BufWritePre handler")
    eq(autocmds("cascade_list_keymaps", "FileType"), keys1, "autocmds: three setups leave one FileType keymap handler")
    eq(autocmds("cascade_list_format", "FileType"), fmt1, "autocmds: three setups leave one FileType format handler")
  end

  do
    -- "save" removed from the triggers: the autocmd must not be registered at
    -- all, and a previous setup's copy must be gone (the augroup is cleared
    -- before the gate is checked, which is what makes that true).
    cascade.setup({ keymaps = { preset = true } })
    eq(autocmds("cascade_renumber_save", "BufWritePre"), 1, "autocmds: fixture has the save handler")

    cascade.setup({ lists = { renumber = { on = { "edit" } } } })
    eq(autocmds("cascade_renumber_save", "BufWritePre"), 0, "autocmds: dropping 'save' removes the handler again")

    cascade.setup({ lists = { renumber = false } })
    eq(autocmds("cascade_renumber_save", "BufWritePre"), 0, "autocmds: renumber = false registers no save handler")

    cascade.setup({ lists = { enable = false } })
    eq(autocmds("cascade_renumber_save", "BufWritePre"), 0, "autocmds: lists disabled registers no save handler")

    cascade.setup({})
    eq(autocmds("cascade_renumber_save", "BufWritePre"), 1, "autocmds: and it comes back with the defaults")
  end

  do
    -- The preset switch decides whether the FileType keymap handler is
    -- registered at all, while the format handler is a `lists` behaviour
    -- and is registered either way.
    cascade.setup({ keymaps = { preset = true } })
    eq(autocmds("cascade_list_keymaps", "FileType") > 0, true, "fixture: the keymap handler is registered with the preset on")

    cascade.setup({ keymaps = { preset = false } })
    eq(autocmds("cascade_list_keymaps", "FileType"), 0, "autocmds: preset = false removes the keymap handler")
    ok(autocmds("cascade_list_format", "FileType") > 0, "autocmds: preset = false keeps the hanging-indent handler")
    eq(autocmds("cascade_renumber_save", "BufWritePre"), 1, "autocmds: ... and the save renumber")
  end

  -- ---------- all three augroups are cleared unconditionally, not just
  -- ---------- when their gate passes, so switching a domain off takes
  -- ---------- effect immediately ----------

  do
    -- `bindings/autocmds.lua`'s module doc says: "Four autocmds, all
    -- idempotent (their augroups are cleared on every setup)".
    --
    -- `setup_save_renumber` calls `lib.augroup(name)` FIRST and checks its
    -- gate afterwards, so the group is emptied on every setup() whether or
    -- not a handler goes back in. `setup_list_keymaps` and
    -- `setup_hanging_indent` now do the same (fixed: they used to `return`
    -- on the gate BEFORE reaching `lib.augroup`, so a setup() that gated
    -- them off never cleared the group and the previous setup()'s handlers
    -- stayed live -- same family as pdfport.nvim's round-14 finding, but the
    -- opposite symptom: there a second setup() *added* a duplicate handler;
    -- here a second setup() failed to *remove* one).
    cascade.setup({ keymaps = { preset = true } })
    local keys = autocmds("cascade_list_keymaps", "FileType")
    local fmt = autocmds("cascade_list_format", "FileType")
    ok(keys > 0 and fmt > 0, "fixture: both FileType handlers are registered")

    -- The preset is switched off: the keymap handler is gone, right away.
    cascade.setup({ keymaps = { preset = false } })
    eq(autocmds("cascade_list_keymaps", "FileType"), 0, "autocmds: preset = false removes the keymap handlers")

    -- The whole list domain is switched off: every handler is gone, the
    -- save renumber included.
    cascade.setup({ keymaps = { preset = true } })
    cascade.setup({ keymaps = { preset = true }, lists = { enable = false } })
    eq(autocmds("cascade_list_keymaps", "FileType"), 0, "autocmds: lists.enable = false removes the keymap handlers")
    eq(autocmds("cascade_list_format", "FileType"), 0, "autocmds: lists.enable = false removes the format handlers")
    eq(autocmds("cascade_renumber_save", "BufWritePre"), 0, "autocmds: ... and the save handler")

    -- Same for an emptied filetype list.
    cascade.setup({ keymaps = { preset = true } })
    cascade.setup({ keymaps = { preset = true }, lists = { filetypes = {} } })
    eq(autocmds("cascade_list_keymaps", "FileType"), 0, "autocmds: lists.filetypes = {} removes the keymap handlers")
    eq(autocmds("cascade_list_format", "FileType"), 0, "autocmds: lists.filetypes = {} removes the format handlers")

    -- The consequence, end to end: with the preset switched off, a matching
    -- FileType event no longer binds any of cascade's buffer-local keys.
    cascade.setup({ keymaps = { preset = true } })
    cascade.setup({ keymaps = { preset = false } })
    local b = H.editable("markdown")
    vim.api.nvim_set_current_buf(b)
    vim.api.nvim_exec_autocmds("FileType", { pattern = "markdown" })
    local bound = 0
    for _, m in ipairs(vim.api.nvim_buf_get_keymap(b, "n")) do
      if m.desc and tostring(m.desc):find("cascade:", 1, true) then
        bound = bound + 1
      end
    end
    eq(bound, 0, "autocmds: no stale handler binds buffer-local keys after preset = false")

    -- A subsequent setup() that turns the domain back on re-establishes it
    -- from scratch -- this is not merely "stopped clearing", the augroup is
    -- genuinely rebuilt on every call.
    cascade.setup({ keymaps = { preset = true } })
    ok(autocmds("cascade_list_keymaps", "FileType") > 0, "autocmds: a later setup() re-registers the keymap handler")
    ok(autocmds("cascade_list_format", "FileType") > 0, "autocmds: ... and the format handler")

    cascade.setup({})
  end

  -- ---------- the save-time renumber, fired for real ----------

  do
    cascade.setup({})
    local b = H.editable("markdown")
    vim.api.nvim_buf_set_lines(b, 0, -1, false, { "1. one", "1. two", "1. three" })
    vim.api.nvim_exec_autocmds("BufWritePre", { buffer = b })
    eq_lines(
      vim.api.nvim_buf_get_lines(b, 0, -1, false),
      { "1. one", "2. two", "3. three" },
      "BufWritePre: the save renumber re-sequences the buffer"
    )

    -- A buffer whose filetype is out of scope is left alone by the same
    -- handler (it re-reads the config and re-checks the filetype per event,
    -- rather than trusting the pattern).
    local b2 = H.editable("lua")
    vim.api.nvim_buf_set_lines(b2, 0, -1, false, { "1. one", "1. two" })
    vim.api.nvim_exec_autocmds("BufWritePre", { buffer = b2 })
    eq_lines(
      vim.api.nvim_buf_get_lines(b2, 0, -1, false),
      { "1. one", "1. two" },
      "BufWritePre: an out-of-scope filetype is skipped"
    )

    -- A scratch buffer is not writable, so the handler must skip it rather
    -- than raise out of a write hook.
    local b3 = H.scratch("markdown")
    vim.api.nvim_buf_set_lines(b3, 0, -1, false, { "1. one", "1. two" })
    ok(
      pcall(vim.api.nvim_exec_autocmds, "BufWritePre", { buffer = b3 }),
      "BufWritePre: a non-writable buffer does not raise out of the handler"
    )
    eq_lines(vim.api.nvim_buf_get_lines(b3, 0, -1, false), { "1. one", "1. two" }, "BufWritePre: ... and is left untouched")
  end

  do
    -- The handler re-reads `lists.renumber.on` at event time, so flipping the
    -- trigger off after setup stops it even though the autocmd is still
    -- registered. (It has to: the augroup is only rebuilt by setup().)
    cascade.setup({})
    local b = H.editable("markdown")
    vim.api.nvim_buf_set_lines(b, 0, -1, false, { "1. one", "1. two" })
    cfg.setup({ lists = { renumber = { on = { "edit" } } } }) -- config only, no re-wire
    vim.api.nvim_exec_autocmds("BufWritePre", { buffer = b })
    eq_lines(
      vim.api.nvim_buf_get_lines(b, 0, -1, false),
      { "1. one", "1. two" },
      "BufWritePre: the handler re-reads the trigger list per event"
    )
    cascade.setup({})
  end

  -- ---------- the FileType handlers, fired for real ----------

  do
    cascade.setup({ keymaps = { preset = true } })
    local b = H.editable("markdown")
    vim.api.nvim_set_current_buf(b)
    -- `pattern` and `buffer` are mutually exclusive here, and FileType matches
    -- on the pattern, so the event is fired against the *current* buffer --
    -- which is how it arrives in real life anyway.
    vim.api.nvim_exec_autocmds("FileType", { pattern = "markdown" })

    -- The format handler sets the hanging-indent options on the buffer.
    ok(vim.bo[b].formatlistpat ~= "", "FileType: formatlistpat was set")
    ok(vim.bo[b].formatoptions:find("n", 1, true) ~= nil, "FileType: 'n' added to formatoptions")

    -- The keymap handler bound the buffer-local list keys.
    local maps = vim.api.nvim_buf_get_keymap(b, "n")
    local found = false
    for _, m in ipairs(maps) do
      if m.desc and tostring(m.desc):find("cascade", 1, true) then
        found = true
      end
    end
    ok(found, "FileType: the buffer-local cascade keys were bound")
  end

  -- ---------- keymaps: feature families ----------

  do
    -- `bind_list_buffer` returns what it registered, so the effect of a
    -- feature switch is observable without reading the keymap table.
    cascade.setup({})
    local b = H.editable("markdown")
    vim.api.nvim_set_current_buf(b)

    local all = lhs_set(keymaps.bind_list_buffer())
    ok(all["<leader>cx"], "bind_list_buffer: the checkbox key is bound by default")
    ok(all["<leader>ct"], "bind_list_buffer: the cycle-type key is bound by default")
    ok(all["<leader>cr"], "bind_list_buffer: renumber is always bound (it has no feature switch)")

    cfg.setup({ lists = { features = { checkbox = false } } })
    local without = lhs_set(keymaps.bind_list_buffer())
    ok(not without["<leader>cx"], "bind_list_buffer: features.checkbox = false drops its key")
    ok(without["<leader>ct"], "bind_list_buffer: ... and leaves the others alone")
    ok(without["<leader>cr"], "bind_list_buffer: ... including the switch-less renumber")

    cfg.setup({ lists = { features = { cycle_type = false } } })
    local no_cycle = lhs_set(keymaps.bind_list_buffer())
    ok(not no_cycle["<leader>ct"], "bind_list_buffer: features.cycle_type = false drops both of its keys")
    ok(not no_cycle["<leader>cT"], "bind_list_buffer: ... the backward one too")
    ok(no_cycle["<leader>cx"], "bind_list_buffer: ... and nothing else")
  end

  do
    -- The switch must be applied to a COPY of the user's keymap table: writing
    -- into the live config would make "this feature is off" and "the user
    -- opted out of this one key" indistinguishable on the next read.
    cascade.setup({ lists = { features = { checkbox = false } }, keymaps = { list = { toggle_checkbox = "<leader>zz" } } })
    local b = H.editable("markdown")
    vim.api.nvim_set_current_buf(b)
    keymaps.bind_list_buffer()
    eq(
      cfg.get("keymaps").list.toggle_checkbox,
      "<leader>zz",
      "bind_list_buffer: the user's keymap table is not rewritten by a feature switch"
    )

    -- Re-enabling the feature must bring the user's own lhs back, which is
    -- only possible because it was never overwritten.
    cfg.setup({ keymaps = { list = { toggle_checkbox = "<leader>zz" } } })
    local back = lhs_set(keymaps.bind_list_buffer())
    ok(back["<leader>zz"], "bind_list_buffer: the user's override survives the feature being switched back on")
    ok(not back["<leader>cx"], "bind_list_buffer: ... and replaces the default lhs")
  end

  do
    -- A per-key opt-out (`= false`) drops just that key, with the feature on.
    cfg.setup({ keymaps = { list = { toggle_checkbox = false } } })
    local b = H.editable("markdown")
    vim.api.nvim_set_current_buf(b)
    local set = lhs_set(keymaps.bind_list_buffer())
    ok(not set["<leader>cx"], "bind_list_buffer: a per-key false drops the key")
    ok(set["<leader>ct"], "bind_list_buffer: ... and only that key")
  end

  -- ---------- keymaps: the global preset ----------

  do
    cfg.setup({})
    local globals = lhs_set(keymaps.bind_preset_globals(cfg.options))
    ok(globals["<C-y>"], "bind_preset_globals: the word-cycle key")
    ok(globals["+"], "bind_preset_globals: the increment alias")
    ok(globals["<leader>cR"], "bind_preset_globals: the selection renumber")
    ok(globals["<A-Right>"], "bind_preset_globals: indent")
    ok(globals["<A-Up>"], "bind_preset_globals: move up")
    ok(globals["<leader><Right>"], "bind_preset_globals: char transpose")
    ok(globals["<leader><C-Right>"], "bind_preset_globals: word transpose")
    -- cycle_char has two lhs on purpose (a terminal may swallow the Ctrl+Alt
    -- form); both must be registered.
    ok(globals["<C-M-y>"], "bind_preset_globals: the Ctrl+Alt char cycle")
    ok(globals["<leader>cy"], "bind_preset_globals: ... and its leader alias")

    -- Each global family gated off by its own domain switch.
    local cases = {
      { opts = { cycle = { enable = false } }, gone = "<C-y>", kept = "<A-Right>", label = "cycle.enable" },
      { opts = { cycle = { features = { word = false } } }, gone = "<C-y>", kept = "<C-M-y>", label = "cycle.features.word" },
      { opts = { cycle = { features = { char = false } } }, gone = "<C-M-y>", kept = "<C-y>", label = "cycle.features.char" },
      { opts = { sequence = { enable = false } }, gone = "<leader>cR", kept = "<C-y>", label = "sequence.enable" },
      {
        opts = { lists = { features = { indent = false } } },
        gone = "<A-Right>",
        kept = "<A-Up>",
        label = "lists.features.indent",
      },
      { opts = { lists = { features = { move = false } } }, gone = "<A-Up>", kept = "<A-Right>", label = "lists.features.move" },
      { opts = { lists = { enable = false } }, gone = "<A-Right>", kept = "<C-y>", label = "lists.enable" },
      {
        opts = { transpose = { enable = false } },
        gone = "<leader><Right>",
        kept = "<C-y>",
        label = "transpose.enable",
      },
      {
        opts = { transpose = { features = { char = false } } },
        gone = "<leader><Right>",
        kept = "<leader><C-Right>",
        label = "transpose.features.char",
      },
      {
        opts = { transpose = { features = { word = false } } },
        gone = "<leader><C-Right>",
        kept = "<leader><Right>",
        label = "transpose.features.word",
      },
    }
    for _, case in ipairs(cases) do
      cfg.setup(case.opts)
      local set = lhs_set(keymaps.bind_preset_globals(cfg.options))
      ok(not set[case.gone], ("bind_preset_globals: %s = false drops %s"):format(case.label, case.gone))
      ok(set[case.kept], ("bind_preset_globals: %s = false keeps %s"):format(case.label, case.kept))
    end
  end

  do
    -- `sequence` is the one family gated on an explicit `enable == false`
    -- rather than on truthiness, so a missing `sequence` table must NOT drop
    -- the key (config.normalize fills it in).
    cfg.setup({})
    local set = lhs_set(keymaps.bind_preset_globals({ keymaps = { globals = {} } }))
    ok(set["<leader>cR"], "bind_preset_globals: an absent sequence table leaves the selection renumber bound")
  end

  -- ---------- bindings.init orchestration ----------

  do
    -- The :Cascade verb is created whether or not the preset is on: it is the
    -- command layer, not a keymap.
    cascade.setup({ keymaps = { preset = false } })
    ok(vim.fn.exists(":Cascade") == 2, "bindings.setup: the :Cascade verb exists without the preset")
    cascade.setup({ keymaps = { preset = true } })
    ok(vim.fn.exists(":Cascade") == 2, "bindings.setup: ... and with it")
  end

  cascade.setup({})
end

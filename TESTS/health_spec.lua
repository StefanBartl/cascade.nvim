-- TESTS/health_spec.lua — `:checkhealth cascade`.
--
-- `cascade.health` had no coverage at all before this spec. It is driven
-- against a captured `vim.health` rather than the real one, so the assertions
-- are about the *report* (which line lands under which severity), not about
-- what checkhealth happens to render on the machine running the suite.
--
-- Two things make that worth doing beyond box-ticking:
--
--   * `M.check()` resolves `vim.health` *inside* the function, so a stub
--     installed just before the call is genuinely the one it uses -- no
--     upvalue was bound at load time.
--   * The "dependency missing" branch is exercised for real (lib.nvim made to
--     fail its `require` via `package.preload`), because the failure mode
--     worth guarding against is a health check that reports the dependency as
--     absent and then calls into it anyway. cascade does not do that -- this
--     pins it.

return function(H)
  local eq = H.eq
  local ok = H.ok

  local health = require("cascade.health")
  local cfg = require("cascade.config")

  --- Run `health.check()` against a captured `vim.health`.
  ---@return table report  # { ok = string[], warn = string[], error = string[], info = string[], start = string[] }
  local function capture()
    local report = { ok = {}, warn = {}, error = {}, info = {}, start = {} }
    local orig = vim.health
    -- Test double over a typed surface; restored right after the call.
    ---@diagnostic disable-next-line: assign-type-mismatch
    vim.health = {
      start = function(m)
        report.start[#report.start + 1] = m
      end,
      ok = function(m)
        report.ok[#report.ok + 1] = m
      end,
      warn = function(m)
        report.warn[#report.warn + 1] = m
      end,
      error = function(m)
        report.error[#report.error + 1] = m
      end,
      info = function(m)
        report.info[#report.info + 1] = m
      end,
    }
    local called_ok, err = pcall(health.check)
    vim.health = orig
    if not called_ok then
      error("health.check() raised: " .. tostring(err), 2)
    end
    return report
  end

  --- Whether any line of `bucket` contains `needle` (plain substring).
  ---@param bucket string[]
  ---@param needle string
  ---@return boolean
  local function has(bucket, needle)
    for i = 1, #bucket do
      if tostring(bucket[i]):find(needle, 1, true) then
        return true
      end
    end
    return false
  end

  -- ---------- the default report ----------

  do
    cfg.setup({})
    local r = capture()

    eq(#r.start, 1, "health: exactly one section")
    eq(r.start[1], "cascade.nvim", "health: section title")

    ok(has(r.ok, "Neovim "), "health: reports the Neovim version")
    -- lib.nvim is on the runtimepath for this suite (CI checks it out as a
    -- sibling), so the required-dependency check has to be on the ok side.
    ok(has(r.ok, "lib.nvim detected"), "health: lib.nvim reported present")
    eq(#r.error, 0, "health: nothing is an error with the defaults")

    ok(has(r.ok, "lists: enabled"), "health: lists enabled")
    ok(has(r.info, "checkbox states: "), "health: checkbox states listed")
    ok(has(r.info, "renumber: on"), "health: renumber triggers listed")
    ok(has(r.ok, "cycle: enabled"), "health: cycle enabled")
    ok(has(r.info, "packs: en, de, dev"), "health: default packs listed in order")
    ok(has(r.info, "number fallback"), "health: number fallback noted")
    ok(has(r.ok, "sequence: enabled"), "health: sequence enabled")
    ok(has(r.info, "sequence start: keep"), "health: default start mode")
    ok(has(r.ok, "transpose: enabled"), "health: transpose enabled")
    ok(has(r.info, "debug: disabled"), "health: debug off by default")
  end

  -- ---------- every domain switched off ----------

  do
    cfg.setup({
      lists = { enable = false },
      cycle = { enable = false },
      sequence = { enable = false },
      transpose = { enable = false },
    })
    local r = capture()
    ok(has(r.info, "lists: disabled"), "health: lists disabled")
    ok(has(r.info, "cycle: disabled"), "health: cycle disabled")
    ok(has(r.info, "sequence: disabled"), "health: sequence disabled")
    ok(has(r.info, "transpose: disabled"), "health: transpose disabled")
    -- The disabled branches must not also emit the enabled ones.
    ok(not has(r.ok, "lists: enabled"), "health: no lists-enabled line when off")
    ok(not has(r.ok, "cycle: enabled"), "health: no cycle-enabled line when off")
  end

  -- ---------- the config-sanity warnings ----------

  do
    cfg.setup({
      lists = {
        checkbox = { states = {} },
        cycle = {},
        forms = {},
      },
    })
    local r = capture()
    ok(has(r.warn, "lists.checkbox.states is empty"), "health: empty checkbox states warns")
    ok(has(r.warn, "lists.cycle is empty"), "health: empty cycle templates warns")
    ok(has(r.warn, "lists.forms is empty"), "health: empty forms warns")
    ok(not has(r.info, "checkbox states: "), "health: no states line when there are none")
  end

  do
    cfg.setup({ lists = { renumber = false } })
    local r = capture()
    ok(has(r.info, "renumber: off"), "health: renumber off reported")
  end

  -- ---------- setup() option validation (ERR-50/ERR-22) ----------

  do
    cfg.setup({})
    eq(#cfg.issues(), 0, "config.issues: nothing to report after a clean setup()")
    local r = capture()
    ok(has(r.ok, "setup() options: all recognised"), "health: clean setup() reports ok")
  end

  do
    -- A typo'd top-level key must not vanish silently into the merge: it is
    -- dropped (the real "lists" stays at its default) and named with a
    -- did-you-mean hint, both from config.issues() and via :checkhealth.
    cfg.setup({ lits = { enable = false } })
    ok(cfg.issues()[1] and cfg.issues()[1]:find("lits", 1, true) ~= nil, "config.issues: names the unknown top-level key")
    ok(cfg.issues()[1]:find("lists", 1, true) ~= nil, "config.issues: suggests the nearest known key")
    eq(cfg.get("lists").enable, true, "config: the typo'd override never reached lists.enable")
    local r = capture()
    ok(has(r.warn, "lits"), "health: reports the unknown key")
  end

  do
    -- Same for a typo one level into a fixed-schema sub-table. When every
    -- sub-key under `lists` is rejected, the leftover override is `{}` --
    -- which must NOT wipe every other `lists` default wholesale (an empty
    -- table is indistinguishable from an array to the merge below, whose
    -- array check replaces the whole key instead of merging it).
    cfg.setup({ lists = { chekbox = { states = { "y", "n" } } } })
    ok(has(cfg.issues(), "lists.chekbox") and has(cfg.issues(), "lists.checkbox"), "config.issues: nested did-you-mean")
    eq(#cfg.get("lists").checkbox.states, 3, "config: the typo'd nested override never reached checkbox.states")
    eq(cfg.get("lists").enable, true, "config: an all-rejected nested table does not wipe sibling lists defaults")
    ok(#cfg.get("lists").types > 0, "config: lists.types survives an all-rejected nested sub-table typo")
    ok(#cfg.get("lists").forms > 0, "config: lists.forms survives an all-rejected nested sub-table typo")
  end

  do
    -- An option table given as a non-table degrades to the default instead
    -- of replacing the whole table and blowing up the first nested read.
    cfg.setup({ lists = false })
    ok(has(cfg.issues(), "must be a table"), "config.issues: mistyped option table reported")
    eq(cfg.get("lists").enable, true, "config: lists falls back to the default when given a non-table")
  end

  do
    -- lists.filetypes / lists.checkbox / lists.continue / cycle.filetypes:
    -- a wrong-typed value degrades to the default instead of throwing the
    -- first time table.concat/opts.checkbox.*/opts.continue.* touches it.
    cfg.setup({
      lists = { filetypes = "markdown", checkbox = false, continue = false },
      cycle = { filetypes = "markdown" },
    })
    local issues = cfg.issues()
    ok(has(issues, "lists.filetypes"), "config.issues: bad lists.filetypes reported")
    ok(has(issues, "lists.checkbox"), "config.issues: bad lists.checkbox reported")
    ok(has(issues, "lists.continue"), "config.issues: bad lists.continue reported")
    ok(has(issues, "cycle.filetypes"), "config.issues: bad cycle.filetypes reported")

    eq(type(cfg.get("lists").filetypes), "table", "config: lists.filetypes degrades to a table")
    eq(type(cfg.get("lists").checkbox), "table", "config: lists.checkbox degrades to a table")
    eq(type(cfg.get("lists").continue), "table", "config: lists.continue degrades to a table")
    eq(cfg.get("cycle").filetypes, nil, "config: cycle.filetypes degrades to nil (every filetype)")

    -- The degraded config must be genuinely usable, not just non-nil: the
    -- exact call sites the findings named (table.concat here; marker/format/
    -- continue elsewhere) must not throw.
    local r = capture()
    ok(has(r.ok, "lists: enabled for"), "health: table.concat(lists.filetypes) survives the degrade")
    ok(#r.error == 0, "health: no error report after degrading a bad lists/cycle shape")
  end

  -- ---------- sequence start mode ----------

  do
    cfg.setup({ sequence = { start = "one" } })
    local r = capture()
    ok(has(r.info, "sequence start: one"), "health: start=one reported")
  end

  -- ---------- debug logging ----------

  do
    cfg.setup({ debug = true })
    local r = capture()
    ok(has(r.ok, "debug: enabled") or has(r.info, "debug: enabled"), "health: debug enabled reported")
    ok(not has(r.info, "debug: disabled"), "health: not both debug branches")
  end

  -- ---------- cycle group conflicts ----------

  do
    -- "no" is both English and Spanish; with both packs on, only the first
    -- one is ever reached, which is exactly what the clash warning is for.
    cfg.setup({ cycle = { packs = { "en", "es" }, groups = {} } })
    local r = capture()
    ok(has(r.warn, "appear in more than one cycle group"), "health: cross-pack clash warned")
    ok(has(r.warn, "wins"), "health: clash names the winner")
  end

  do
    -- A single pack cannot clash with itself, and an own group that repeats a
    -- pack's group verbatim is redundant rather than shadowing -- neither may
    -- produce the warning, or it would fire on a perfectly ordinary config.
    cfg.setup({ cycle = { packs = { "en" }, groups = {} } })
    local r = capture()
    ok(not has(r.warn, "appear in more than one cycle group"), "health: one pack alone does not clash")
  end

  do
    cfg.setup({ cycle = { packs = {}, groups = { { "on", "off" } } } })
    local r = capture()
    ok(has(r.info, "packs: none"), "health: no packs reported explicitly")
    ok(has(r.ok, "1 own groups"), "health: own group count reported")
  end

  do
    -- More than eight clashing words must be truncated with a count, not
    -- dumped in full.
    local groups = { { "x", "y" } }
    for i = 1, 10 do
      groups[#groups + 1] = { "w" .. i, "z" .. i }
      groups[#groups + 1] = { "w" .. i, "q" .. i }
    end
    cfg.setup({ cycle = { packs = {}, groups = groups } })
    local r = capture()
    ok(has(r.warn, "and 2 more"), "health: long clash list is truncated")
  end

  -- ---------- lib.nvim reported absent ----------

  do
    -- The failure family this check exists for: a health check that reports a
    -- dependency as missing and then calls straight into it anyway (found in
    -- three other repos during this campaign). cascade's error branch only
    -- reports -- pinned here by making the require fail for real and
    -- requiring that check() still returns normally.
    local name = "lib.nvim.bindings.usercmd.composer"
    local saved = package.loaded[name]
    package.loaded[name] = nil
    package.preload[name] = function()
      error("simulated: lib.nvim not installed")
    end

    cfg.setup({})
    local r = capture() -- raises through pcall above if the branch calls in
    ok(has(r.error, "lib.nvim not found"), "health: missing lib.nvim is an error")
    ok(not has(r.ok, "lib.nvim detected"), "health: not both lib.nvim branches")
    -- The rest of the report must still be produced: a missing optional-ish
    -- accessor is not a reason to stop reporting on the domains.
    ok(has(r.ok, "lists: enabled"), "health: keeps going after the lib.nvim error")
    ok(has(r.ok, "transpose: enabled"), "health: reaches the last domain too")

    package.preload[name] = nil
    package.loaded[name] = saved
  end

  -- ---------- which-key ----------

  do
    -- which-key is not installed in the headless runtimepath, so the "info"
    -- branch is the live one; the present branch is driven by faking the
    -- module in package.loaded.
    cfg.setup({})
    local r = capture()
    ok(has(r.info, "which-key not found"), "health: which-key absent branch")

    local saved = package.loaded["which-key"]
    package.loaded["which-key"] = {}
    local r2 = capture()
    package.loaded["which-key"] = saved
    ok(has(r2.ok, "which-key detected"), "health: which-key present branch")
  end

  -- ---------- a config module that cannot load ----------

  do
    -- health.check() warns and returns instead of letting the load error
    -- escape into :checkhealth.
    local saved = package.loaded["cascade.config"]
    package.loaded["cascade.config"] = nil
    package.preload["cascade.config"] = function()
      error("simulated: broken config module")
    end

    local r = capture()
    ok(has(r.warn, "config module failed to load"), "health: config load failure warns")
    eq(#r.ok, 1, "health: stops after the version line when config is broken")

    package.preload["cascade.config"] = nil
    package.loaded["cascade.config"] = saved
  end

  -- Leave the shared config in its default state for the specs that follow.
  cfg.setup({})
end

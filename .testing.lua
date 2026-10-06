-- .testing.lua -- configuration of testing.nvim for this project.
-- Written by `testing migrate`; edit freely (it is never overwritten). Every key is optional; the
-- keys are documented in testing.nvim's docs/CONFIG.md. Loading this file executes it (same trust
-- as running the specs).
return {
  -- Lua module root of the project.
  plugin = "cascade",
  -- How the spec files are run: "auto" = sniffed per file, "h" = on the project's own TESTS/harness.lua,
  -- "script" = a self-running script in its own process.
  dialect = "h",
  -- Dependencies (directory names) put on the runtimepath: $<NAME>_DIR, .deps/<name>, ../<name>,
  -- stdpath('data')/lazy/<name>.
  deps = { "lib.nvim", "ui.nvim" },
  -- "none" = all specs in one nvim, "file" = one nvim per spec file
  -- (nothing leaks from one file into the next). "file" here because setup() leaves plugin-global
  -- state (autocmd groups, :Cascade, keymaps, 'operatorfunc') and the specs leave scratch buffers
  -- behind; in a one-case child that dies with the process instead of being a state finding.
  isolated = "file",
  -- Guards (safety nets, see testing.nvim docs/GUARDS.md). The suite passes all of them cleanly
  -- (no file writes outside the temp dir, no processes, no network, no prompts), so all are errors.
  guards = {
    fs = "error",
    state = "error",
    scheduled_error = "error",
    prompt = "error",
    deprecation = "error",
    process_net = "error",
  },
  -- Nothing to allow: cascade.nvim neither writes files, starts processes nor opens connections.
  guard_allow = { fs = {}, spawn = {}, network = {} },
}

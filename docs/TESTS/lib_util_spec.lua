-- docs/TESTS/lib_util_spec.lua — cascade.util.lib's soft bridge to lib.nvim.
--
-- The headless test runner (`-u NONE -c "set rtp+=."`) never puts the real
-- lib.nvim checkout on package.path, so lib.nvim is genuinely absent here —
-- that covers the fallback path for free. The "lib.nvim present" path is
-- covered by stubbing `package.loaded` with fakes that mirror lib.nvim's
-- real exported shapes (`lib.nvim.notify` -> `.create(prefix)` returning a
-- notifier, `lib.nvim.map` -> a bare function, `lib.nvim.autocmd.augroup`
-- -> `{ create = { clear = fn } }`), so a portable spec can prove
-- cascade.util.lib actually calls through to lib.nvim rather than only
-- ever exercising the fallback.

return function(H)
  local eq = H.eq
  local ok = H.ok

  -- Fresh module each time: it holds no state itself, but re-requiring
  -- after clearing package.loaded keeps this spec independent of load order.
  package.loaded["cascade.util.lib"] = nil
  local lib = require("cascade.util.lib")

  -- lib.nvim absent: M.notify falls back to vim.notify.
  do
    local captured
    local orig = vim.notify
    vim.notify = function(msg, level, opts)
      captured = { msg = msg, level = level, opts = opts }
    end
    lib.notify("hello", vim.log.levels.WARN)
    vim.notify = orig
    ok(captured, "vim.notify fallback invoked")
    eq(captured.msg, "[cascade] hello", "fallback notify prefixes message")
    eq(captured.level, vim.log.levels.WARN, "fallback notify passes level")
  end

  -- lib.nvim absent: M.map falls back to vim.keymap.set.
  do
    local captured
    local orig = vim.keymap.set
    vim.keymap.set = function(mode, lhs, rhs, opts)
      captured = { mode = mode, lhs = lhs, rhs = rhs, opts = opts }
    end
    local rhs = function() end
    lib.map("n", "<Plug>(cascade-test)", rhs, { desc = "test" })
    vim.keymap.set = orig
    ok(captured, "vim.keymap.set fallback invoked")
    eq(captured.mode, "n", "fallback map passes mode")
    eq(captured.lhs, "<Plug>(cascade-test)", "fallback map passes lhs")
    eq(captured.rhs, rhs, "fallback map passes rhs")
  end

  -- lib.nvim absent: M.augroup falls back to nvim_create_augroup.
  do
    local id = lib.augroup("cascade_test_augroup_fallback")
    eq(type(id), "number", "fallback augroup returns a numeric id")
    ok(id > 0, "fallback augroup id is a real (positive) augroup id")
  end

  -- lib.nvim present (stubbed): M.notify calls through to lib.nvim.notify's
  -- create(prefix)/.notify(msg, level) shape, not vim.notify.
  do
    local captured
    package.loaded["lib.nvim.notify"] = {
      create = function(prefix)
        return {
          notify = function(msg, level)
            captured = { prefix = prefix, msg = msg, level = level }
          end,
        }
      end,
    }

    local vim_notify_called = false
    local orig = vim.notify
    vim.notify = function()
      vim_notify_called = true
    end
    lib.notify("hi", vim.log.levels.INFO)
    vim.notify = orig
    package.loaded["lib.nvim.notify"] = nil

    ok(captured, "lib.nvim.notify path invoked when present")
    eq(captured.prefix, "[cascade]", "lib.nvim.notify.create called with cascade prefix")
    eq(captured.msg, "hi", "lib.nvim.notify path passes message through")
    ok(not vim_notify_called, "vim.notify fallback NOT used when lib.nvim.notify succeeds")
  end

  -- lib.nvim present (stubbed): M.map calls through to lib.nvim.map's bare
  -- function shape, not vim.keymap.set.
  do
    local captured
    package.loaded["lib.nvim.map"] = function(modes, lhs, rhs, opts)
      captured = { modes = modes, lhs = lhs, rhs = rhs, opts = opts }
    end

    local vim_map_called = false
    local orig = vim.keymap.set
    vim.keymap.set = function()
      vim_map_called = true
    end
    local rhs = function() end
    lib.map("v", "<Plug>(cascade-test-2)", rhs, {})
    vim.keymap.set = orig
    package.loaded["lib.nvim.map"] = nil

    ok(captured, "lib.nvim.map path invoked when present")
    eq(captured.modes, "v", "lib.nvim.map path passes mode through")
    eq(captured.lhs, "<Plug>(cascade-test-2)", "lib.nvim.map path passes lhs through")
    ok(not vim_map_called, "vim.keymap.set fallback NOT used when lib.nvim.map succeeds")
  end

  -- lib.nvim present (stubbed): M.augroup calls through to
  -- lib.nvim.autocmd.augroup's `{ create = { clear = fn } }` shape.
  do
    local captured_name
    package.loaded["lib.nvim.autocmd.augroup"] = {
      create = {
        clear = function(name)
          captured_name = name
          return -12345 -- sentinel: nvim_create_augroup never returns a negative id
        end,
      },
    }

    local id = lib.augroup("cascade_test_augroup_bridged")
    package.loaded["lib.nvim.autocmd.augroup"] = nil

    eq(captured_name, "cascade_test_augroup_bridged", "lib.nvim.autocmd.augroup path passes name through")
    eq(id, -12345, "lib.nvim.autocmd.augroup path's return value is used, not a fresh nvim_create_augroup id")
  end
end

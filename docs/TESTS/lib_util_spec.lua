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

  -- dotrepeat_run: without vim-repeat installed, the wrapped fn still runs
  -- via the plain operatorfunc/g@l trick (repeat#set is simply absent; the
  -- pcall around it swallows the "unknown function" error).
  do
    local dotrepeat = require("cascade.util.dotrepeat")
    local fired = false
    local run = dotrepeat.repeatable("test_no_vim_repeat", function()
      fired = true
    end)
    run()
    vim.api.nvim_feedkeys("", "x", false) -- flush the queued g@l
    ok(fired, "dotrepeat_run: wrapped fn still runs with no vim-repeat installed")
  end

  -- dotrepeat_run: with vim-repeat installed, also calls repeat#set("g@l").
  -- repeat#set is a real Vimscript *autoload* function -- Vim/Neovim only
  -- allows `function! repeat#set(...)` inside a properly named
  -- autoload/repeat.vim, so a minimal fake is written to a temp dir and
  -- added to 'runtimepath' just for this test (mirrors what installing
  -- tpope/vim-repeat provides).
  do
    local tmp = vim.fn.tempname()
    vim.fn.mkdir(tmp .. "/autoload", "p")
    local f = assert(io.open(tmp .. "/autoload/repeat.vim", "w"))
    f:write("function! repeat#set(seq, ...) abort\n")
    f:write("  let g:cascade_test_repeat_seq = a:seq\n")
    f:write("  let g:cascade_test_repeat_calls = get(g:, 'cascade_test_repeat_calls', 0) + 1\n")
    f:write("endfunction\n")
    f:close()
    vim.o.runtimepath = vim.o.runtimepath .. "," .. tmp
    vim.g.cascade_test_repeat_calls = 0

    local dotrepeat = require("cascade.util.dotrepeat")
    local fired = false
    local run = dotrepeat.repeatable("test_vim_repeat", function()
      fired = true
    end)
    run()
    vim.api.nvim_feedkeys("", "x", false)

    ok(fired, "dotrepeat_run: wrapped fn still runs with vim-repeat installed")
    eq(vim.g.cascade_test_repeat_calls, 1, "dotrepeat_run: repeat#set was called once")
    eq(vim.g.cascade_test_repeat_seq, "g@l", "dotrepeat_run: repeat#set was told to replay g@l")
  end

  -- debug_log: disabled is a true no-op (no notify, no logger call at all).
  do
    package.loaded["cascade.util.lib"] = nil
    local lib2 = require("cascade.util.lib")
    local notified = false
    local orig = vim.notify
    vim.notify = function()
      notified = true
    end
    lib2.debug_log(false, "should not appear")
    vim.notify = orig
    ok(not notified, "debug_log: disabled never notifies")
  end

  -- debug_log: enabled, no lib.nvim.logger installed -> falls back to
  -- vim.notify at DEBUG level (the same tier lib.nvim.logger.debug() maps
  -- to). This test's rtp genuinely has lib.nvim (and its logger submodule)
  -- checked out as a sibling, so "absent" is simulated via package.preload:
  -- a require() with package.loaded[name] cleared runs the searchers, and
  -- preload (checked before the path searcher) errors instead of finding
  -- the real module -- try_require's pcall then correctly reports it absent.
  do
    package.loaded["cascade.util.lib"] = nil
    package.loaded["lib.nvim.logger"] = nil
    package.preload["lib.nvim.logger"] = function()
      error("simulated absent for this test")
    end
    local lib2 = require("cascade.util.lib")
    local captured
    local orig = vim.notify
    vim.notify = function(msg, level)
      captured = { msg = msg, level = level }
    end
    lib2.debug_log(true, "hello", { x = 1 })
    vim.notify = orig
    package.preload["lib.nvim.logger"] = nil
    ok(captured, "debug_log: fallback vim.notify invoked when enabled and no logger")
    eq(captured.level, vim.log.levels.DEBUG, "debug_log: fallback uses DEBUG level")
    ok(captured.msg:find("hello", 1, true) ~= nil, "debug_log: fallback message includes the text")
  end

  -- debug_log: enabled, lib.nvim.logger present (stubbed) -> calls through to
  -- its .new({name=...}).debug(msg, ctx) shape, not vim.notify.
  do
    package.loaded["cascade.util.lib"] = nil
    local captured
    package.loaded["lib.nvim.logger"] = {
      new = function(opts)
        return {
          debug = function(msg, ctx)
            captured = { name = opts.name, msg = msg, ctx = ctx }
          end,
        }
      end,
    }
    local lib2 = require("cascade.util.lib")
    local notify_called = false
    local orig = vim.notify
    vim.notify = function()
      notify_called = true
    end
    lib2.debug_log(true, "world", { y = 2 })
    vim.notify = orig
    package.loaded["lib.nvim.logger"] = nil

    ok(captured, "debug_log: lib.nvim.logger path invoked when present")
    eq(captured.name, "cascade", "debug_log: logger created with name=cascade")
    eq(captured.msg, "world", "debug_log: message passed through")
    eq(captured.ctx.y, 2, "debug_log: ctx table passed through")
    ok(not notify_called, "debug_log: vim.notify fallback NOT used when lib.nvim.logger succeeds")
  end

  -- cascade.dispatch is instrumented with debug_log at its detect/advance/
  -- fallback points (cascade.debug config flag). Force a fresh cascade.util.lib
  -- (dispatch.lua's own require) with lib.nvim.logger stubbed absent, so
  -- debug output surfaces via the vim.notify fallback and not a logger
  -- instance left cached by an earlier test block in this same file.
  do
    package.loaded["cascade.util.lib"] = nil
    package.loaded["lib.nvim.logger"] = nil
    package.preload["lib.nvim.logger"] = function()
      error("simulated absent for this test")
    end
    package.loaded["cascade.dispatch"] = nil
    local dispatch = require("cascade.dispatch")
    local cfg = require("cascade.config")
    local Context = require("cascade.core.context")

    cfg.setup({ debug = true })
    local notifications = {}
    local orig = vim.notify
    vim.notify = function(msg)
      notifications[#notifications + 1] = msg
    end

    local ctx = Context.new()
    local handled = dispatch.try({
      function()
        return false
      end,
    }, ctx)
    vim.notify = orig

    eq(handled, false, "dispatch.try: still returns false when no handler matches")
    ok(#notifications > 0, "dispatch.try: debug = true produces debug output")
    local joined = table.concat(notifications, " | ")
    ok(joined:find("handler tried", 1, true) ~= nil, "dispatch.try: logs each handler attempt")
    ok(joined:find("no handler matched", 1, true) ~= nil, "dispatch.try: logs the final no-match result")

    -- debug = false (default): the exact same call produces no debug output.
    cfg.setup({})
    local notified_again = false
    vim.notify = function()
      notified_again = true
    end
    dispatch.try({
      function()
        return false
      end,
    }, ctx)
    vim.notify = orig
    ok(not notified_again, "dispatch.try: debug = false produces no debug output")

    package.preload["lib.nvim.logger"] = nil
    cfg.setup({})
  end
end

-- Headless smoke test for cascade.nvim. Run with:
--   nvim --headless -u NONE -c "set rtp+=." -c "luafile scripts/smoke.lua" -c "qa!"
--
-- This is a thin entry point kept for backwards compatibility / CI. The actual
-- specs live in docs/TESTS/ and are executed by docs/TESTS/run.lua (the single
-- source of truth). On success this prints CASCADE_SMOKE_OK; on failure the
-- runner exits non-zero before we get here.

local root = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
dofile(root .. "../docs/TESTS/run.lua")

print("CASCADE_SMOKE_OK")

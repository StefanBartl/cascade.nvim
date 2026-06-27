-- Headless smoke test for cascade.nvim. Run with:
--   nvim --headless -u NONE -c "set rtp+=." -c "luafile scripts/smoke.lua" -c "qa!"
-- Exits non-zero on the first failed assertion.

local function eq(a, b, msg)
  if a ~= b then
    error(("FAIL %s: expected %q, got %q"):format(msg or "", tostring(b), tostring(a)), 2)
  end
end

-- 1. modules load
local marker = require("cascade.lists.marker")
local roman = require("cascade.lists.roman")
local alpha = require("cascade.lists.alpha")
local cfg = require("cascade.config")
cfg.setup({ lists = { types = { "unordered", "digit", "ascii", "roman" } } })
local lopts = cfg.get("lists")

-- 2. roman / alpha round-trips
eq(roman.to_roman(4), "IV", "roman 4")
eq(roman.to_roman(2024), "MMXXIV", "roman 2024")
eq(roman.to_int("IV"), 4, "roman parse IV")
eq(roman.to_int("IIII"), nil, "roman reject IIII")
eq(alpha.to_alpha(1), "a", "alpha 1")
eq(alpha.to_alpha(27), "aa", "alpha 27")
eq(alpha.to_int("aa"), 27, "alpha parse aa")

-- 3. marker parse + advance + render
local m = marker.parse("  1. hello", lopts)
eq(m and m.kind, "digit", "digit kind")
eq(m.marker, "1", "digit marker")
eq(m.indent, "  ", "indent")
local nxt = marker.advance(m, lopts)
eq(nxt.marker, "2", "advance digit")
eq(marker.render(nxt), "  2. ", "render next")

local cb = marker.parse("- [ ] task", lopts)
eq(cb and cb.checkbox, " ", "checkbox inner")
eq(cb.text, "task", "checkbox text")

local rm = marker.parse("IV) item", lopts)
eq(rm and rm.kind, "roman", "roman kind")
eq(marker.advance(rm, lopts).marker, "V", "advance roman IV->V")

eq(marker.parse("just text", lopts), nil, "non-list line")

-- 4. buffer-level: continuation + renumber via the facade
local buf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_set_current_buf(buf)
vim.bo[buf].filetype = "markdown"
local cascade = require("cascade")
cascade.setup({})

vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "1. one", "2. two" })
-- toggle checkbox on line 1 should promote to checkbox
vim.api.nvim_win_set_cursor(0, { 1, 0 })
require("cascade.lists.checkbox").toggle(require("cascade.core.context").new(), lopts)
local l1 = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1]
eq(l1, "1. [ ] one", "checkbox promote")

-- renumber after a manual insert
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "1. a", "1. b", "1. c" })
require("cascade.lists.renumber").run(buf, 1, lopts)
local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
eq(lines[2], "2. b", "renumber l2")
eq(lines[3], "3. c", "renumber l3")

-- 5. word cycle
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "local x = true" })
vim.api.nvim_win_set_cursor(0, { 1, 11 }) -- on "true"
local copts = cfg.get("cycle")
local ok = require("cascade.cycle.word_cycle").cycle(require("cascade.core.context").new(), copts, 1)
eq(ok, true, "word cycle handled")
eq(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1], "local x = false", "true->false")

print("CASCADE_SMOKE_OK")

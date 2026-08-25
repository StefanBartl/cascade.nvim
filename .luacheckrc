-- luacheck configuration for cascade.nvim
std = "luajit"
-- `vim` is writable (we set vim.o.*, vim.bo[buf].* etc.); `read_globals` would
-- flag those field assignments as "setting a read-only field".
globals = { "vim" }
max_line_length = 130

-- docs/BINDINGS.md is a manually column-aligned data table (documentation),
-- not runtime code; its alignment intentionally exceeds the line limit.
exclude_files = { "docs/BINDINGS.md" }

-- Each case in the specs gets its own `do ... end` block and deliberately
-- reuses the same names (scol/ecol/changed/new_ecol) the case before it used --
-- that repetition is what lets the cases be read side by side. Shadowing is
-- the point there, so W421 is not a finding under TESTS/.
files["TESTS/"] = {
  ignore = { "421" },
}

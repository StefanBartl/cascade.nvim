-- docs/TESTS/units_spec.lua — pure functions: roman, alpha, marker.
---@diagnostic disable: missing-fields, need-check-nil, param-type-mismatch

return function(H)
  local eq = H.eq
  local marker = require("cascade.lists.marker")
  local roman = require("cascade.lists.roman")
  local alpha = require("cascade.lists.alpha")
  local cfg = require("cascade.config")
  cfg.setup({ lists = { types = { "unordered", "digit", "ascii", "roman" } } })
  local lopts = cfg.get("lists")

  -- roman / alpha round-trips
  eq(roman.to_roman(4), "IV", "roman 4")
  eq(roman.to_roman(2024), "MMXXIV", "roman 2024")
  eq(roman.to_int("IV"), 4, "roman parse IV")
  eq(roman.to_int("IIII"), nil, "roman reject IIII")
  eq(alpha.to_alpha(1), "a", "alpha 1")
  eq(alpha.to_alpha(27), "aa", "alpha 27")
  eq(alpha.to_int("aa"), 27, "alpha parse aa")

  -- marker parse + advance + render
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

  cfg.setup({})
end

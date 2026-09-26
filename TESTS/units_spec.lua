-- TESTS/units_spec.lua — pure functions: roman, alpha, marker.
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

  -- advance on a checkbox item resets the checkbox to the first configured
  -- state, whatever the source item's own state was -- the next item in a
  -- checklist starts unchecked, not carrying the previous one's "done".
  local checked = marker.parse("- [x] done task", lopts)
  eq(checked and checked.checkbox, "x", "checkbox item is checked")
  local cb_next = marker.advance(checked, lopts)
  eq(cb_next.checkbox, " ", "advance checkbox: resets to the first configured state")
  eq(cb_next.text, "", "advance checkbox: text is cleared like any other advance")
  eq(marker.render(cb_next), "- [ ] ", "advance checkbox: renders unchecked")

  local rm = marker.parse("IV) item", lopts)
  eq(rm and rm.kind, "roman", "roman kind")
  eq(marker.advance(rm, lopts).marker, "V", "advance roman IV->V")

  eq(marker.parse("just text", lopts), nil, "non-list line")

  -- Bare markers: no trailing space at all (see marker.lua's try_kind doc --
  -- this is what a freshly continued, still-empty item looks like once a
  -- whitespace-trimming `BufWritePre` autocmd strips the trailing space
  -- `marker.render` wrote before any text was typed into it). Must still
  -- parse as an (empty) item, not fall through to "not a list line".
  local bare_digit = marker.parse("  5.", lopts)
  eq(bare_digit and bare_digit.kind, "digit", "bare digit kind")
  eq(bare_digit and bare_digit.marker, "5", "bare digit marker")
  eq(bare_digit and bare_digit.delim, ".", "bare digit delim")
  eq(bare_digit and bare_digit.indent, "  ", "bare digit indent")
  eq(bare_digit and bare_digit.text, "", "bare digit text is empty, not nil")
  eq(bare_digit and bare_digit.checkbox, nil, "bare digit has no checkbox")
  eq(marker.render(bare_digit) .. bare_digit.text, "  5. ", "bare digit re-renders with the space back")

  local bare_paren = marker.parse("4)", lopts)
  eq(bare_paren and bare_paren.marker, "4", "bare digit marker, paren delim")
  eq(bare_paren and bare_paren.delim, ")", "bare digit paren delim")

  local bare_ascii = marker.parse("b.", lopts)
  eq(bare_ascii and bare_ascii.kind, "ascii", "bare ascii kind")
  eq(bare_ascii and bare_ascii.marker, "b", "bare ascii marker")

  -- `roman` deliberately does NOT get the bare-marker fallback: `%a+` is an
  -- unbounded letter run, and ordinary words built only from I/V/X/L/C/D/M
  -- are, by coincidence, well-formed Roman numerals ("Mix." = 1009,
  -- "Civ." = 104) -- a bare match would silently turn real prose into a
  -- list marker and let renumber.tree lowercase/rewrite it on save.
  eq(marker.parse("IV.", lopts), nil, "bare roman-shaped token stays unrecognized (no space+text to anchor on)")
  eq(marker.parse("Mix.", lopts), nil, "regression: a word that is coincidentally valid Roman must not parse")
  eq(marker.parse("Civ.", lopts), nil, "regression: same for another real-word/Roman-numeral collision")

  local bare_bullet = marker.parse("-", lopts)
  eq(bare_bullet and bare_bullet.kind, "unordered", "bare unordered kind")
  eq(bare_bullet and bare_bullet.marker, "-", "bare unordered marker")
  eq(bare_bullet and bare_bullet.text, "", "bare unordered text is empty, not nil")

  -- multi-byte checkbox states (emoji), gated behind explicit config
  cfg.setup({ lists = { types = { "unordered", "digit" }, checkbox = { states = { "🔲", "✅", "❌" } } } })
  local eopts = cfg.get("lists")

  local em = marker.parse("- [✅] done", eopts)
  eq(em and em.checkbox, "✅", "emoji checkbox inner")
  eq(em.text, "done", "emoji checkbox text")
  eq(marker.render(em) .. em.text, "- [✅] done", "emoji checkbox render round-trip")

  local vs = marker.parse("- [☑️] variation selector", eopts)
  eq(vs and vs.checkbox, nil, "unconfigured multi-byte state does not parse as checkbox")
  eq(vs and vs.text, "[☑️] variation selector", "unrecognized bracket payload kept as plain text")

  local link = marker.parse("- [see docs](url)", eopts)
  eq(link and link.checkbox, nil, "markdown link label is not mistaken for a checkbox")
  eq(link and link.text, "[see docs](url)", "markdown link label kept as plain text")

  cfg.setup({})
end

-- TESTS/multibyte_spec.lua — byte-vs-character offsets in real buffers.
--
-- Every write cascade makes is byte-addressed: `nvim_buf_set_text` takes byte
-- columns, `nvim_win_set_cursor` takes a byte column, `token.span` and
-- `letter.step_at` read byte indices out of a Lua string, and
-- `sequence.span`/`span_multi` slice a line with `string.sub`. A single
-- character-indexed offset anywhere in that chain lands mid-codepoint and
-- shreds a glyph -- and the existing specs work almost entirely in ASCII, so
-- nothing held that chain in place.
--
-- The expected offsets below are hand-counted in BYTES, spelled out in the
-- comments, so a change that starts counting characters somewhere fails here
-- rather than silently producing mojibake in a user's buffer:
--
--   "ä"/"ö"/"ü"/"ß"  2 bytes (U+00E4 …)
--   "日"/"本"/"語"    3 bytes (U+65E5 …)
--   "🎉"             4 bytes (U+1F389)
--
-- Each case asserts the resulting buffer text *and*, where a position is
-- returned or moved, the numeric offset -- asserting only the text would let
-- a wrong-but-unused offset through.

return function(H)
  local eq = H.eq
  local ok = H.ok

  local cfg = require("cascade.config")
  local cascade = require("cascade")
  local sequence = require("cascade.sequence.renumber")
  local token = require("cascade.cycle.token")
  local letter = require("cascade.cycle.letter")
  local marker = require("cascade.lists.marker")

  --- Fresh editable buffer preloaded with `lines`.
  ---@param lines string[]
  ---@param ft string|nil
  ---@return integer bufnr
  local function buf_with(lines, ft)
    local b = H.editable(ft or "markdown")
    vim.api.nvim_buf_set_lines(b, 0, -1, false, lines)
    return b
  end

  --- One buffer line (0-based).
  ---@param b integer
  ---@param row integer
  ---@return string
  local function line_at(b, row)
    return vim.api.nvim_buf_get_lines(b, row, row + 1, false)[1]
  end

  cfg.setup({})

  -- ---------- the byte widths this spec counts with ----------

  do
    eq(#"ä", 2, "fixture: ä is 2 bytes")
    eq(#"ß", 2, "fixture: ß is 2 bytes")
    eq(#"日", 3, "fixture: 日 is 3 bytes")
    eq(#"🎉", 4, "fixture: 🎉 is 4 bytes")
    -- vim.str_utfindex would disagree with all four; that difference is the
    -- whole point of this file.
    eq(vim.fn.strchars("ä日🎉"), 3, "fixture: three characters, eight bytes")
    eq(#"ä日🎉", 9, "fixture: ... nine bytes, counting the terminator-free string")
  end

  -- ---------- token.span over multibyte neighbours ----------

  do
    -- "Über yes danach": Ü is 2 bytes, so "yes" starts at byte 6, not 5.
    local line = "Über yes danach"
    eq(#line, 16, "token.span fixture: 16 bytes for 15 characters")

    local s, e, text = token.span(line, 6)
    eq(s, 6, "token.span: start byte of 'yes'")
    eq(e, 9, "token.span: end byte (exclusive) of 'yes'")
    eq(text, "yes", "token.span: the token itself")

    -- The cursor sitting on the *second* byte of Ü must still report the
    -- whole word, at its byte bounds.
    local s2, e2, text2 = token.span(line, 0)
    eq(s2, 0, "token.span: 'Über' starts at byte 0")
    eq(e2, 5, "token.span: 'Über' ends at byte 5 (4 chars, 5 bytes)")
    eq(text2, "Über", "token.span: multibyte word returned whole")

    -- A byte index past the end of the last token finds nothing rather than
    -- clamping into it.
    eq(token.span("äöü", 6), nil, "token.span: past the end returns nil")
  end

  -- ---------- word cycle inside multibyte surroundings ----------

  do
    cfg.setup({ cycle = { packs = { "en" } } })
    local b = buf_with({ "Über yes danach" })
    vim.api.nvim_win_set_cursor(0, { 1, 6 }) -- first byte of "yes"
    cascade.cycle_word_next()
    eq(line_at(b, 0), "Über no danach", "cycle word: replaced in place, Ü and the tail intact")
  end

  do
    -- The German pack, cycling a word that is itself multibyte, with the
    -- replacement a different byte width ("ja" 2 bytes -> "nein" 4 bytes).
    cfg.setup({ cycle = { packs = { "de" }, groups = { { "größer", "kleiner" } } } })
    local b = buf_with({ "ist größer als" })
    vim.api.nvim_win_set_cursor(0, { 1, 4 }) -- "größer" starts at byte 4
    cascade.cycle_word_next()
    eq(line_at(b, 0), "ist kleiner als", "cycle word: a multibyte token replaced by a narrower one")
    -- ... and back, widening again.
    vim.api.nvim_win_set_cursor(0, { 1, 4 })
    cascade.cycle_word_next()
    eq(line_at(b, 0), "ist größer als", "cycle word: and back, widening the line again")
  end

  -- ---------- letter / char cycle must not split a codepoint ----------

  do
    -- `letter.step_at` reads exactly one byte. On a UTF-8 lead or
    -- continuation byte that byte is >= 0x80, never an a-z/A-Z letter, so
    -- the only correct outcome is a refusal -- stepping it would write a
    -- replacement byte into the middle of the glyph.
    local s, e, repl = letter.step_at("Grüße", 2, 1) -- byte 2 = lead byte of "ü"
    eq(s, nil, "letter.step_at: refuses on a multibyte lead byte")
    eq(e, nil, "letter.step_at: no end offset either")
    eq(repl, nil, "letter.step_at: no replacement either")

    eq(select(1, letter.step_at("Grüße", 3, 1)), nil, "letter.step_at: refuses on a continuation byte too")

    -- The ASCII letters around it are still reachable, at their byte offsets.
    local s2, e2, repl2 = letter.step_at("Grüße", 1, 1) -- "r"
    eq(s2, 1, "letter.step_at: ASCII before the glyph, start byte")
    eq(e2, 2, "letter.step_at: ASCII before the glyph, end byte")
    eq(repl2, "s", "letter.step_at: r -> s")

    local s3 = select(1, letter.step_at("Grüße", 6, 1)) -- "e", after ü(2) and ß(2)
    eq(s3, 6, "letter.step_at: ASCII after two 2-byte glyphs sits at byte 6")
  end

  do
    cfg.setup({})
    local b = buf_with({ "Grüße" })
    vim.api.nvim_win_set_cursor(0, { 1, 2 }) -- on "ü"
    cascade.cycle_char_next()
    eq(line_at(b, 0), "Grüße", "cycle char: a no-op on a glyph leaves the line byte-identical")
    eq(#line_at(b, 0), 7, "cycle char: ... and byte-identical in length (5 chars, 7 bytes)")

    vim.api.nvim_win_set_cursor(0, { 1, 6 }) -- the trailing "e"
    cascade.cycle_char_next()
    eq(line_at(b, 0), "Grüßf", "cycle char: the ASCII letter past the glyphs is still reachable")
  end

  -- ---------- sequence: charwise span on a line with glyphs ----------

  do
    cfg.setup({})
    local seq = cfg.get("sequence")

    -- "Größe 5. und 9. Stück"
    -- Counted explicitly: G(1) r(1) ö(2) ß(2) e(1) ' '(1) = 8 bytes before
    -- the first ordinal, for six characters.
    local text = "Größe 5. und 9. Stück"
    eq(text:sub(1, 8), "Größe ", "sequence fixture: eight bytes precede the first ordinal")
    eq(vim.fn.strchars(text:sub(1, 8)), 6, "sequence fixture: ... which is six characters")
    eq(text:sub(9, 10), "5.", "sequence fixture: the first ordinal sits at bytes 8-9")

    local b = buf_with({ text })
    local changed, new_ecol = sequence.span(b, 0, 0, #text - 1, seq)
    ok(changed, "sequence.span: rewrote the selection")
    eq(line_at(b, 0), "Größe 5. und 6. Stück", "sequence.span: 9. renumbered to 6., every glyph intact")
    eq(new_ecol, #line_at(b, 0) - 1, "sequence.span: the returned end column is a byte offset into the new line")
    eq(#line_at(b, 0), #text, "sequence.span: same byte length, since 9. and 6. are the same width")
  end

  do
    -- A rewrite that *widens* the line (9. -> 10.) past multibyte text: the
    -- returned end column has to grow by exactly one byte.
    cfg.setup({ sequence = { start = "keep" } })
    local seq = cfg.get("sequence")
    local text = "Süß 9. und 9. Maß"
    local b = buf_with({ text })
    local changed, new_ecol = sequence.span(b, 0, 0, #text - 1, seq)
    ok(changed, "sequence.span: widening rewrite happened")
    eq(line_at(b, 0), "Süß 9. und 10. Maß", "sequence.span: 9. -> 10. across the glyphs")
    eq(#line_at(b, 0), #text + 1, "sequence.span: exactly one byte wider")
    eq(new_ecol, #text, "sequence.span: the end column grew with the line")
    eq(new_ecol, #line_at(b, 0) - 1, "sequence.span: ... and still points at the line's last byte")
  end

  do
    -- An already-correct sequence is left alone, and says so, rather than
    -- rewriting the line to itself.
    cfg.setup({ sequence = { start = "keep" } })
    local seq = cfg.get("sequence")
    local text = "Süß 9. und 10. Maß"
    local b = buf_with({ text })
    local changed, new_ecol = sequence.span(b, 0, 0, #text - 1, seq)
    ok(not changed, "sequence.span: an already-correct sequence reports no change")
    eq(line_at(b, 0), text, "sequence.span: ... and leaves the line byte-identical")
    eq(new_ecol, #text - 1, "sequence.span: the end column is handed back unchanged")
  end

  do
    cfg.setup({ sequence = { start = "one" } })
    local seq = cfg.get("sequence")
    -- start = "one" forces a restart, so 9. -> 1. and 10. -> 2.: the line
    -- gets *narrower* by two bytes while the trailing "Maß" must survive.
    local text = "Süß 9. und 10. Maß"
    local b = buf_with({ text })
    local changed, new_ecol = sequence.span(b, 0, 0, #text - 1, seq)
    ok(changed, "sequence.span: start=one rewrote the run")
    eq(line_at(b, 0), "Süß 1. und 2. Maß", "sequence.span: narrowing rewrite keeps the trailing glyphs")
    eq(new_ecol, #line_at(b, 0) - 1, "sequence.span: the end column tracked the shrink")
    eq(#line_at(b, 0), #text - 1, "sequence.span: exactly one byte shorter")
  end

  do
    -- A selection that starts *after* a glyph: the untouched prefix must come
    -- back byte-identical, which is only true if scol is treated as a byte
    -- offset throughout.
    cfg.setup({ sequence = { start = "one" } })
    local seq = cfg.get("sequence")
    local text = "Präfix: 7. eins 8. zwei"
    -- P(1) r(1) ä(2) f(1) i(1) x(1) :(1) ' '(1) = 9 bytes of prefix.
    eq(text:sub(1, 9), "Präfix: ", "sequence fixture: nine bytes of prefix")
    local b = buf_with({ text })
    local changed = sequence.span(b, 0, 9, #text - 1, seq)
    ok(changed, "sequence.span: mid-line selection rewrote")
    eq(line_at(b, 0), "Präfix: 1. eins 2. zwei", "sequence.span: the glyph-bearing prefix is untouched")
  end

  do
    -- Multi-line charwise selection carrying the counter across lines that
    -- hold 3- and 4-byte characters.
    cfg.setup({ sequence = { start = "one" } })
    local seq = cfg.get("sequence")
    local b = buf_with({ "頭 5. eins", "🎉 9. zwei", "Süß 4. drei ende" })
    local last = line_at(b, 2)
    -- Select from byte 0 of row 0 through the byte before " ende" on row 2.
    local ecol = #"Süß 4. drei" - 1
    local changed, new_ecol = sequence.span_multi(b, 0, 0, 2, ecol, seq)
    ok(changed, "sequence.span_multi: rewrote across the rows")
    H.eq_lines(vim.api.nvim_buf_get_lines(b, 0, -1, false), {
      "頭 1. eins",
      "🎉 2. zwei",
      "Süß 3. drei ende",
    }, "sequence.span_multi: one sequence across 3- and 4-byte glyphs")
    eq(new_ecol, ecol, "sequence.span_multi: the end column is unchanged (same-width rewrite)")
    eq(#line_at(b, 2), #last, "sequence.span_multi: the last row kept its byte length")
  end

  -- ---------- list markers with multibyte item text ----------

  do
    cfg.setup({})
    local lopts = cfg.get("lists")

    local m = marker.parse("  3. Grüße aus Köln", lopts)
    eq(m and m.kind, "digit", "marker.parse: kind through multibyte text")
    eq(m.indent, "  ", "marker.parse: indent is bytes of whitespace")
    eq(m.text, "Grüße aus Köln", "marker.parse: the multibyte tail comes back whole")
    eq(marker.render(m), "  3. ", "marker.render: prefix unaffected by the tail")
  end

  do
    cfg.setup({})
    local b = buf_with({ "1. 🎉 party", "1. 日本語", "1. Grüße" })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    cascade.renumber()
    H.eq_lines(vim.api.nvim_buf_get_lines(b, 0, -1, false), {
      "1. 🎉 party",
      "2. 日本語",
      "3. Grüße",
    }, "renumber: only the markers change; emoji and CJK item text survive")
  end

  -- ---------- indent moves the cursor by BYTES ----------

  do
    cfg.setup({})
    local b = buf_with({ "- Ölkanne für Süßes" })
    vim.bo[b].expandtab = true
    vim.bo[b].shiftwidth = 2
    -- Cursor on the "Ö" (byte 2: "-" is 1, " " is 1).
    vim.api.nvim_win_set_cursor(0, { 1, 2 })
    cascade.indent()
    eq(line_at(b, 0), "  - Ölkanne für Süßes", "indent: two spaces prepended, glyphs untouched")
    -- The indent added two bytes, so the cursor must sit two bytes further
    -- along -- still on the "Ö", not inside it.
    eq(vim.api.nvim_win_get_cursor(0)[2], 4, "indent: the cursor moved by the byte width of the new indent")
    eq(line_at(b, 0):sub(5, 6), "Ö", "indent: byte 4 is still the lead byte of Ö")

    cascade.dedent()
    eq(line_at(b, 0), "- Ölkanne für Süßes", "dedent: back to the original line")
    eq(vim.api.nvim_win_get_cursor(0)[2], 2, "dedent: the cursor moved back by the same byte width")
  end

  -- ---------- transpose across multibyte neighbours ----------

  do
    cfg.setup({})
    local b = buf_with({ "日本語 word" })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    cascade.swap_word_right()
    eq(line_at(b, 0), "word 日本語", "transpose word: a 9-byte CJK word swaps with a 4-byte ASCII one")
    eq(#line_at(b, 0), 14, "transpose word: byte length preserved (9 + 1 + 4)")
  end

  do
    cfg.setup({})
    -- Single-character swap where both sides are multibyte.
    local b = buf_with({ "äö" })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    cascade.swap_right()
    eq(line_at(b, 0), "öä", "transpose char: two 2-byte glyphs swap whole")
    eq(#line_at(b, 0), 4, "transpose char: still four bytes, no split codepoint")
  end

  do
    cfg.setup({})
    -- Asymmetric widths: a 4-byte emoji and a 1-byte letter.
    local b = buf_with({ "🎉x" })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    cascade.swap_right()
    eq(line_at(b, 0), "x🎉", "transpose char: emoji and ASCII swap whole")
    eq(#line_at(b, 0), 5, "transpose char: five bytes preserved")
    eq(vim.fn.strchars(line_at(b, 0)), 2, "transpose char: still two characters")
  end

  -- ---------- quick toggles on glyph-bearing lines ----------

  do
    cfg.setup({})
    local b = buf_with({ "Müsli für alle" })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    cascade.bullet_toggle()
    eq(line_at(b, 0), "- Müsli für alle", "bullet toggle: marker prepended, glyphs untouched")
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    cascade.bullet_toggle()
    eq(line_at(b, 0), "Müsli für alle", "bullet toggle: and removed again, byte-identical")
  end

  do
    cfg.setup({})
    local b = buf_with({ "- [ ] Grüße schreiben" })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    cascade.toggle_checkbox()
    eq(line_at(b, 0), "- [x] Grüße schreiben", "checkbox: state advanced, item text intact")
  end

  cfg.setup({})
end

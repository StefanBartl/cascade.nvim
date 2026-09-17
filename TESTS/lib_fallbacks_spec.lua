-- TESTS/lib_fallbacks_spec.lua — `cascade.util.lib`'s *standalone* fallbacks.
--
-- `lib_util_spec.lua` covers the three bridges whose fallback is a native API
-- (notify -> vim.notify, map -> vim.keymap.set, augroup ->
-- nvim_create_augroup). The four remaining bridges fall back to a real
-- reimplementation living in this module -- case classification, case
-- application, Roman numerals and alphabetic ordinals -- and those bodies had
-- no coverage at all: `lib.nvim` is on the runtimepath for this suite, so
-- every call went to `lib.lua.strings.case` / `lib.lua.numeral` and the local
-- copies were dead code as far as the tests were concerned.
--
-- That is the wrong way round for a *fallback*: it is the path a user without
-- lib.nvim's Lua half gets, so it is the path most likely to drift away from
-- the library it mirrors. Each case below is therefore asserted twice -- once
-- with lib.nvim present (the bridge) and once with the specific lib module
-- made absent (the fallback) -- and the two results have to agree.

return function(H)
  local eq = H.eq
  local ok = H.ok

  package.loaded["cascade.util.lib"] = nil
  local lib = require("cascade.util.lib")

  --- Run `fn` with `mod` made unrequireable, then restore it.
  ---@generic T
  ---@param mod string
  ---@param fn fun(): T
  ---@return T
  local function without(mod, fn)
    local saved = package.loaded[mod]
    package.loaded[mod] = nil
    package.preload[mod] = function()
      error("simulated: " .. mod .. " not installed")
    end
    local got, res = pcall(fn)
    package.preload[mod] = nil
    package.loaded[mod] = saved
    if not got then
      error(res, 2)
    end
    return res
  end

  -- ---------- the lib modules really are present by default ----------

  do
    ok(pcall(require, "lib.lua.strings.case"), "fixture: lib.lua.strings.case is available")
    ok(pcall(require, "lib.lua.numeral"), "fixture: lib.lua.numeral is available")
  end

  -- ---------- case_shape ----------

  do
    local cases = {
      { input = "word", want = "lower" },
      { input = "WORD", want = "upper" },
      { input = "Word", want = "capital" },
      { input = "wOrD", want = "mixed" },
      { input = "", want = "lower" },
      -- A single letter is both lower and "capital"; lower wins, since the
      -- `s == s:lower()` test comes first.
      { input = "a", want = "lower" },
      { input = "A", want = "upper" },
      -- Digits and punctuation are caseless, so they read as lower.
      { input = "42", want = "lower" },
      { input = "==", want = "lower" },
      -- A capitalized word with an uppercase tail is mixed, not capital.
      { input = "WOrd", want = "mixed" },
    }
    for _, case in ipairs(cases) do
      local bridged = lib.case_shape(case.input)
      local fell_back = without("lib.lua.strings.case", function()
        return lib.case_shape(case.input)
      end)
      eq(bridged, case.want, ("case_shape(%q) via lib.nvim"):format(case.input))
      eq(fell_back, case.want, ("case_shape(%q) via the fallback"):format(case.input))
    end
  end

  -- ---------- apply_shape ----------

  do
    local cases = {
      { repl = "yes", shape = "lower", want = "yes" },
      { repl = "yes", shape = "upper", want = "YES" },
      { repl = "yes", shape = "capital", want = "Yes" },
      -- "mixed" is deliberately a pass-through: there is no rule that could
      -- reproduce an arbitrary capitalization on a different word.
      { repl = "yEs", shape = "mixed", want = "yEs" },
      -- An already-capitalized replacement is normalized, not left alone.
      { repl = "YES", shape = "capital", want = "Yes" },
      { repl = "YES", shape = "lower", want = "yes" },
      { repl = "", shape = "capital", want = "" },
      -- Multi-word replacements only get their first letter capitalized.
      { repl = "in progress", shape = "capital", want = "In progress" },
    }
    for _, case in ipairs(cases) do
      local bridged = lib.apply_shape(case.repl, case.shape)
      local fell_back = without("lib.lua.strings.case", function()
        return lib.apply_shape(case.repl, case.shape)
      end)
      eq(bridged, case.want, ("apply_shape(%q, %s) via lib.nvim"):format(case.repl, case.shape))
      eq(fell_back, case.want, ("apply_shape(%q, %s) via the fallback"):format(case.repl, case.shape))
    end
  end

  -- ---------- roman numerals ----------

  do
    local to_roman = {
      { 1, "I" },
      { 4, "IV" },
      { 9, "IX" },
      { 14, "XIV" },
      { 40, "XL" },
      { 90, "XC" },
      { 400, "CD" },
      { 900, "CM" },
      { 1987, "MCMLXXXVII" },
      { 2024, "MMXXIV" },
      { 3999, "MMMCMXCIX" },
    }
    for _, case in ipairs(to_roman) do
      local n, want = case[1], case[2]
      eq(lib.roman_to_roman(n), want, ("roman_to_roman(%d) via lib.nvim"):format(n))
      eq(
        without("lib.lua.numeral", function()
          return lib.roman_to_roman(n)
        end),
        want,
        ("roman_to_roman(%d) via the fallback"):format(n)
      )
    end

    -- Out of range and wrong type both yield nil rather than a broken string.
    for _, bad in ipairs({ 0, -1, 4000 }) do
      eq(lib.roman_to_roman(bad), nil, ("roman_to_roman(%d) is out of range"):format(bad))
      eq(
        without("lib.lua.numeral", function()
          return lib.roman_to_roman(bad)
        end),
        nil,
        ("roman_to_roman(%d) is out of range (fallback)"):format(bad)
      )
    end
    eq(
      without("lib.lua.numeral", function()
        ---@diagnostic disable-next-line: param-type-mismatch
        return lib.roman_to_roman("nope")
      end),
      nil,
      "roman_to_roman: a non-number is refused (fallback)"
    )
    -- A fractional value is floored rather than refused.
    eq(
      without("lib.lua.numeral", function()
        return lib.roman_to_roman(4.7)
      end),
      "IV",
      "roman_to_roman: a fraction is floored (fallback)"
    )

    local to_int = {
      { "I", 1 },
      { "IV", 4 },
      { "iv", 4 },
      { "MMXXIV", 2024 },
      { "mmmcmxcix", 3999 },
    }
    for _, case in ipairs(to_int) do
      local s, want = case[1], case[2]
      eq(lib.roman_to_int(s), want, ("roman_to_int(%q) via lib.nvim"):format(s))
      eq(
        without("lib.lua.numeral", function()
          return lib.roman_to_int(s)
        end),
        want,
        ("roman_to_int(%q) via the fallback"):format(s)
      )
    end

    -- Non-canonical and non-Roman input is refused by round-tripping the
    -- parsed value, which is what keeps a word like "MIX" from being read as
    -- a numeral by accident... except that "MIX" IS canonical (1009), so the
    -- interesting rejections are the repeated-digit forms.
    for _, bad in ipairs({ "IIII", "VV", "IC", "XXXX", "", "hello", "MMMM", "4" }) do
      eq(lib.roman_to_int(bad), nil, ("roman_to_int(%q) is refused via lib.nvim"):format(bad))
      eq(
        without("lib.lua.numeral", function()
          return lib.roman_to_int(bad)
        end),
        nil,
        ("roman_to_int(%q) is refused via the fallback"):format(bad)
      )
    end
    -- A genuinely canonical word-looking numeral is accepted, deliberately.
    eq(
      without("lib.lua.numeral", function()
        return lib.roman_to_int("MIX")
      end),
      1009,
      "roman_to_int: a canonical word-shaped numeral is accepted (fallback)"
    )
  end

  -- ---------- alphabetic ordinals ----------

  do
    local to_alpha = {
      { 1, "a" },
      { 26, "z" },
      { 27, "aa" },
      { 52, "az" },
      { 53, "ba" },
      { 702, "zz" },
      { 703, "aaa" },
    }
    for _, case in ipairs(to_alpha) do
      local n, want = case[1], case[2]
      eq(lib.alpha_to_alpha(n), want, ("alpha_to_alpha(%d) via lib.nvim"):format(n))
      eq(
        without("lib.lua.numeral", function()
          return lib.alpha_to_alpha(n)
        end),
        want,
        ("alpha_to_alpha(%d) via the fallback"):format(n)
      )
    end

    for _, bad in ipairs({ 0, -3 }) do
      eq(lib.alpha_to_alpha(bad), nil, ("alpha_to_alpha(%d) is refused"):format(bad))
      eq(
        without("lib.lua.numeral", function()
          return lib.alpha_to_alpha(bad)
        end),
        nil,
        ("alpha_to_alpha(%d) is refused (fallback)"):format(bad)
      )
    end

    local to_int = {
      { "a", 1 },
      { "z", 26 },
      { "aa", 27 },
      { "AA", 27 },
      { "zz", 702 },
    }
    for _, case in ipairs(to_int) do
      local s, want = case[1], case[2]
      eq(lib.alpha_to_int(s), want, ("alpha_to_int(%q) via lib.nvim"):format(s))
      eq(
        without("lib.lua.numeral", function()
          return lib.alpha_to_int(s)
        end),
        want,
        ("alpha_to_int(%q) via the fallback"):format(s)
      )
    end

    for _, bad in ipairs({ "", "a1", "1", "a-b", " a" }) do
      eq(lib.alpha_to_int(bad), nil, ("alpha_to_int(%q) is refused"):format(bad))
      eq(
        without("lib.lua.numeral", function()
          return lib.alpha_to_int(bad)
        end),
        nil,
        ("alpha_to_int(%q) is refused (fallback)"):format(bad)
      )
    end

    -- Round-trip both directions, through the fallback, over a range wide
    -- enough to cross both carry boundaries.
    without("lib.lua.numeral", function()
      for n = 1, 800 do
        local s = lib.alpha_to_alpha(n)
        eq(lib.alpha_to_int(s), n, ("alpha round-trip %d"):format(n))
      end
      return true
    end)
  end

  -- ---------- the numeral wrappers the list modules use ----------

  do
    -- `lists.roman`/`lists.alpha` are one-line re-exports of these, so the
    -- fallback has to satisfy them too -- that is what `lists/marker.lua`
    -- classifies ordered markers with.
    local roman = require("cascade.lists.roman")
    local alpha = require("cascade.lists.alpha")
    without("lib.lua.numeral", function()
      eq(roman.to_roman(2024), "MMXXIV", "lists.roman uses the fallback transparently")
      eq(roman.to_int("MMXXIV"), 2024, "lists.roman parses through the fallback")
      eq(alpha.to_alpha(27), "aa", "lists.alpha uses the fallback transparently")
      eq(alpha.to_int("aa"), 27, "lists.alpha parses through the fallback")
      return true
    end)
  end
end

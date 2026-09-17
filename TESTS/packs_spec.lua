-- TESTS/packs_spec.lua — the shipped cycle packs as *data*, plus resolve()'s
-- cache and its warn-once behaviour.
--
-- `cycle_spec.lua` already drives `resolve`/`conflicts` as functions, but it
-- only ever loads "en", "de", "es" and "dev" -- the five remaining language
-- packs ("fr", "it", "nl", "pt", "ru") were never required by the suite at
-- all, so a typo in one of them (an empty entry, a one-element group, the
-- same word twice) shipped unnoticed. Those three shapes are not cosmetic:
-- a group with fewer than two distinct entries makes the cycle a no-op, and
-- a repeated word makes it stall on the repeat -- which is precisely why
-- `cascade.cycle_group_add` rejects both at runtime. The packs deserve the
-- same contract.

return function(H)
  local eq = H.eq
  local ok = H.ok

  local packs = require("cascade.cycle.packs")

  -- ---------- every shipped pack, as data ----------

  eq(#packs.KNOWN, 9, "packs.KNOWN: nine shipped packs")

  for _, name in ipairs(packs.KNOWN) do
    local loaded, groups = pcall(require, "cascade.cycle.packs." .. name)
    ok(loaded, ("pack %s loads"):format(name))
    eq(type(groups), "table", ("pack %s is a table"):format(name))
    ok(#groups > 0, ("pack %s is not empty"):format(name))

    for gi = 1, #groups do
      local grp = groups[gi]
      local where = ("pack %s group %d"):format(name, gi)
      eq(type(grp), "table", where .. " is a table")
      ok(#grp >= 2, where .. " has at least two entries")

      local seen = {}
      for ei = 1, #grp do
        local entry = grp[ei]
        eq(type(entry), "string", ("%s entry %d is a string"):format(where, ei))
        ok(entry ~= "", ("%s entry %d is non-empty"):format(where, ei))
        eq(entry, vim.trim(entry), ("%s entry %d carries no stray whitespace"):format(where, ei))
        -- A word repeated inside one group makes `word_cycle` stall on the
        -- repeat instead of advancing -- the same defect `cycle_group_add`
        -- refuses to accept from a user.
        ok(not seen[entry], ("%s entry %d (%q) is not a duplicate"):format(where, ei, entry))
        seen[entry] = true
      end
    end
  end

  -- Every pack must be requireable under exactly the name KNOWN lists, since
  -- `resolve` builds the module path from it.
  for _, name in ipairs(packs.KNOWN) do
    eq(type(package.loaded["cascade.cycle.packs." .. name]), "table", ("pack %s resolves by its KNOWN name"):format(name))
  end

  -- ---------- resolution cache ----------

  do
    packs.invalidate()
    local a = packs.resolve({ "fr" })
    local b = packs.resolve({ "fr" })
    ok(a == b, "resolve: the same pack list hits the cache (identity, not a fresh table)")
    ok(#a > 0, "resolve: the fr pack yields groups")

    packs.invalidate()
    local c = packs.resolve({ "fr" })
    ok(c ~= a, "invalidate(): the next resolve rebuilds")
    eq(#c, #a, "invalidate(): the rebuild yields the same number of groups")
  end

  do
    -- Order is precedence, so the two orderings must be distinct results and
    -- must not share a cache slot.
    packs.invalidate()
    local it_pt = packs.resolve({ "it", "pt" })
    local pt_it = packs.resolve({ "pt", "it" })
    ok(it_pt ~= pt_it, "resolve: the cache key is order-sensitive")
    eq(#it_pt, #pt_it, "resolve: both orderings concatenate the same groups")
    eq(#it_pt, #packs.resolve({ "it" }) + #packs.resolve({ "pt" }), "resolve: concatenation is total")
  end

  -- ---------- unknown names ----------

  do
    packs.invalidate() -- also clears the warn-once memo
    local seen = {}
    local orig = vim.notify
    -- Test double over a typed surface; restored right after the case.
    ---@diagnostic disable-next-line: duplicate-set-field
    vim.notify = function(msg)
      seen[#seen + 1] = tostring(msg)
    end

    local out = packs.resolve({ "nl", "definitely-not-a-pack", "ru" })
    -- Resolve again: the warning is memoized per name, so it must not repeat
    -- (this runs on every keypress through `groups_for`).
    packs.invalidate() -- drops the result cache but keeps... nothing: see below
    local out2 = packs.resolve({ "nl", "definitely-not-a-pack", "ru" })
    vim.notify = orig

    eq(#out, #packs.resolve({ "nl" }) + #packs.resolve({ "ru" }), "resolve: an unknown name is skipped, the known ones survive")
    eq(#out2, #out, "resolve: the unknown name stays skipped on a rebuild")
    ok(#seen >= 1, "resolve: an unknown pack name warns")
    ok(seen[1]:find("definitely-not-a-pack", 1, true) ~= nil, "resolve: the warning names the offending pack")
    ok(seen[1]:find("known:", 1, true) ~= nil, "resolve: the warning lists the known packs")
    -- `invalidate()` deliberately clears the warn memo along with the result
    -- cache (a re-setup() with the same typo should say so again), so the
    -- second pass warns once more -- but never more than once per pass.
    eq(#seen, 2, "resolve: exactly one warning per pass, not one per lookup")
  end

  -- ---------- the default pack set stays conflict-free ----------

  do
    -- Also asserted in cycle_spec for the config defaults; repeated here over
    -- the raw pack data so a pack edit is caught by the pack spec itself.
    local effective = {}
    for _, g in ipairs(packs.resolve({ "en", "de", "dev" })) do
      effective[#effective + 1] = g
    end
    eq(#packs.conflicts(effective), 0, "packs: the default set { en, de, dev } does not shadow a word")
  end

  do
    -- Every pack on at once is *expected* to clash (that is what the health
    -- warning is for) -- what must hold is that `conflicts` survives the full
    -- set and reports each shadowed word only once.
    local all = packs.resolve(packs.KNOWN)
    local clashes = packs.conflicts(all)
    local words = {}
    for i = 1, #clashes do
      ok(not words[clashes[i].word], ("conflicts: %q reported only once"):format(clashes[i].word))
      words[clashes[i].word] = true
      ok(clashes[i].winner ~= clashes[i].shadowed, "conflicts: winner and shadowed are different groups")
    end
    ok(#clashes > 0, "packs: all nine packs at once do shadow words (the health warning has a subject)")
  end

  packs.invalidate()
end

-- TESTS/menu_spec.lua — `cascade.integrations.menu`.
--
-- Had no coverage at all: nothing in the suite required the module, so the
-- gates it promises ("the menu never offers anything the keyboard wouldn't")
-- were unverified, and a `ui.contextmenu` API drift would have surfaced only
-- in a user's right-click menu.
--
-- `ui.nvim` is a real CI sibling checkout here (cycle_spec already drives
-- `ui.kit.select` for real), so `ui.contextmenu`'s `entry`/`group`/`submenu`
-- are the genuine ones -- no stub. Only `open()` is never called: that is the
-- renderer, which needs a live window.

return function(H)
  local eq = H.eq
  local ok = H.ok

  local cfg = require("cascade.config")
  local cascade = require("cascade")
  local menu = require("cascade.integrations.menu")

  --- Entry labels of `items`, separators and headings dropped.
  ---@param items table[]
  ---@return string[]
  local function labels(items)
    local out = {}
    for i = 1, #items do
      local it = items[i]
      if it.name ~= "separator" and not it.__heading then
        out[#out + 1] = it.name
      end
    end
    return out
  end

  --- Whether any entry's label contains `needle`.
  ---@param items table[]
  ---@param needle string
  ---@return boolean
  local function offers(items, needle)
    for _, label in ipairs(labels(items)) do
      if label:find(needle, 1, true) then
        return true
      end
    end
    return false
  end

  cascade.setup({})

  -- ---------- the full set ----------

  do
    local b = H.editable("markdown")
    local items = menu.items(b)
    ok(#items > 0, "menu.items: a configured filetype yields entries")

    for _, want in ipairs({
      "Toggle checkbox",
      "Cycle list marker type",
      "Cycle list marker type back",
      "Renumber list",
      "Rotate list form",
      "Sort list A-Z",
      "Reverse list order",
      "Strip checkboxes",
    }) do
      ok(offers(items, want), ("menu.items offers %q"):format(want))
    end

    -- Every entry is callable and carries the keymap hint the preset uses, so
    -- a host can render it without knowing anything about cascade.
    for i = 1, #items do
      local it = items[i]
      if it.name ~= "separator" then
        eq(type(it.cmd), "function", ("menu.items entry %d is callable"):format(i))
        eq(type(it.rtxt), "string", ("menu.items entry %d carries a keymap hint"):format(i))
      end
    end

    -- Three groups means two separators (a separator is only inserted when
    -- something already stands above it).
    local separators = 0
    for i = 1, #items do
      if items[i].name == "separator" then
        separators = separators + 1
      end
    end
    eq(separators, 2, "menu.items: three groups, two separators")
    ok(items[1].name ~= "separator", "menu.items: no leading separator")
    ok(items[#items].name ~= "separator", "menu.items: no trailing separator")
  end

  do
    -- The default bufnr is the current buffer.
    local b = H.editable("markdown")
    vim.api.nvim_set_current_buf(b)
    eq(#menu.items(), #menu.items(b), "menu.items: defaults to the current buffer")
  end

  -- ---------- the gates ----------

  do
    cfg.setup({ lists = { enable = false } })
    local b = H.editable("markdown")
    eq(#menu.items(b), 0, "menu.items: lists disabled yields nothing")

    cfg.setup({})
    local b2 = H.editable("lua")
    eq(#menu.items(b2), 0, "menu.items: an unconfigured filetype yields nothing")

    -- A buffer with no filetype at all is likewise out of scope (the default
    -- `lists.filetypes` is a concrete list, so "" is not in it).
    local b3 = H.editable(nil)
    eq(#menu.items(b3), 0, "menu.items: an unset filetype yields nothing")
  end

  do
    -- `lists.filetypes = nil` is documented as "every filetype" (matching
    -- `bindings/autocmds`' own `ft_in`), so a lua buffer becomes in-scope.
    -- A nil cannot be expressed in a merged table literal, so the option is
    -- cleared on the live config to reach the branch.
    cfg.setup({})
    local live = cfg.get("lists")
    local saved = live.filetypes
    live.filetypes = nil
    local b = H.editable("lua")
    ok(#menu.items(b) > 0, "menu.items: filetypes = nil means every filetype")
    live.filetypes = saved
  end

  do
    -- Each feature switch removes exactly its own entries -- the same gates
    -- `bind_list_buffer` applies, which is the module's stated contract.
    local cases = {
      { feature = "checkbox", gone = "Toggle checkbox", kept = "Sort list A-Z" },
      { feature = "cycle_type", gone = "Cycle list marker type", kept = "Toggle checkbox" },
      { feature = "rotate", gone = "Rotate list form", kept = "Sort list A-Z" },
      { feature = "sort", gone = "Sort list A-Z", kept = "Reverse list order" },
      { feature = "reverse", gone = "Reverse list order", kept = "Sort list A-Z" },
      { feature = "strip", gone = "Strip checkboxes", kept = "Renumber list" },
    }
    for _, case in ipairs(cases) do
      cfg.setup({ lists = { features = { [case.feature] = false } } })
      local b = H.editable("markdown")
      local items = menu.items(b)
      ok(not offers(items, case.gone), ("menu.items: features.%s = false drops %q"):format(case.feature, case.gone))
      ok(offers(items, case.kept), ("menu.items: features.%s = false keeps %q"):format(case.feature, case.kept))
    end

    -- `cycle_type` gates BOTH of its entries, forward and back.
    cfg.setup({ lists = { features = { cycle_type = false } } })
    local b = H.editable("markdown")
    ok(not offers(menu.items(b), "Cycle list marker type back"), "menu.items: features.cycle_type drops the backward entry too")
  end

  do
    -- Renumber has no feature switch of its own (every other list action
    -- leans on it), so it survives every combination.
    cfg.setup({
      lists = {
        features = {
          checkbox = false,
          cycle_type = false,
          rotate = false,
          sort = false,
          reverse = false,
          strip = false,
        },
      },
    })
    local b = H.editable("markdown")
    local items = menu.items(b)
    eq(#labels(items), 1, "menu.items: with every switch off, one entry remains")
    ok(offers(items, "Renumber list"), "menu.items: ... and it is the switch-less renumber")
    -- The two emptied groups must not leave stray separators behind.
    for i = 1, #items do
      ok(items[i].name ~= "separator", "menu.items: an emptied group leaves no separator")
    end
  end

  -- ---------- submenu ----------

  do
    cfg.setup({})
    local b = H.editable("markdown")
    local sub = menu.submenu(nil, b)
    ok(sub ~= nil, "menu.submenu: built for a configured buffer")
    ok(type(sub.items) == "table" and #sub.items > 0, "menu.submenu: carries the entries")
    eq(sub.name, "  Cascade", "menu.submenu: the default label")

    local named = menu.submenu("My Lists", b)
    eq(named.name, "My Lists", "menu.submenu: an explicit label is used")

    -- Nothing to show means nil, so a host can chain it without an extra
    -- emptiness check.
    cfg.setup({ lists = { enable = false } })
    eq(menu.submenu(nil, b), nil, "menu.submenu: nil when there is nothing to offer")
  end

  -- ---------- the entries actually do something ----------

  do
    -- The menu binds the facade functions themselves, so invoking an entry has
    -- to have the same effect as the corresponding key.
    cfg.setup({})
    local b = H.editable("markdown")
    vim.api.nvim_set_current_buf(b)
    vim.api.nvim_buf_set_lines(b, 0, -1, false, { "- one" })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })

    local items = menu.items(b)
    local toggle
    for i = 1, #items do
      if items[i].name and items[i].name:find("Toggle checkbox", 1, true) then
        toggle = items[i].cmd
      end
    end
    ok(toggle ~= nil, "menu.items: the checkbox entry was found")
    toggle()
    H.eq_lines(
      vim.api.nvim_buf_get_lines(b, 0, -1, false),
      { "- [ ] one" },
      "menu.items: invoking the entry toggles the checkbox"
    )
  end

  cascade.setup({})
end

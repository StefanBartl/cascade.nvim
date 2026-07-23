---@module 'cascade.bindings.keymaps'
---@brief The buffer-local list keys and the preset globals.
---@description
--- Maps keys straight onto the facade actions in `cascade` — no `<Plug>`
--- indirection. which-key (if installed) labels the `<leader>c` prefix via
--- `cascade.bindings.which_key`; individual key descriptions come from each
--- mapping's `desc`.

local lib = require("cascade.util.lib")

local M = {}

--- Bind buffer-local list keys for the current buffer (only enabled features).
--- Called from the FileType autocmd in `cascade.bindings.autocmds`.
---@return nil
function M.bind_list_buffer()
  local api = require("cascade")
  local feat = require("cascade.config").get("lists").features or {}
  local function on(name)
    return feat[name] ~= false
  end
  local function map(mode, lhs, rhs, desc)
    lib.map(mode, lhs, rhs, { buffer = true, silent = true, desc = desc })
  end

  if on("continue") then
    map("i", "<CR>", api.cr, "cascade: continue list")
    map("n", "o", api.o, "cascade: open item below")
    map("n", "O", api.O, "cascade: open item above")
  end
  if on("checkbox") then
    map("n", "<leader>cx", api.toggle_checkbox, "cascade: toggle checkbox")
  end
  if on("bullet_toggle") then
    map("n", "<A-->", api.bullet_toggle, "cascade: toggle bullet point")
    map("x", "<A-->", api.bullet_toggle_visual, "cascade: toggle bullet point")
    map("n", "<A-*>", api.star_toggle, "cascade: toggle star bullet")
    map("x", "<A-*>", api.star_toggle_visual, "cascade: toggle star bullet")
  end
  if on("number_toggle") then
    map("n", "<A-0>", api.number_toggle, "cascade: toggle numbered list")
    map("x", "<A-0>", api.number_toggle_visual, "cascade: toggle numbered list")
  end
  if on("checkbox_toggle") then
    map("n", "<A-c>", api.checkbox_toggle, "cascade: toggle checkbox bullet")
    map("x", "<A-c>", api.checkbox_toggle_visual, "cascade: toggle checkbox bullet")
  end
  if on("cycle_type") then
    map("n", "<leader>ct", api.cycle_type_next, "cascade: cycle list type")
    map("n", "<leader>cT", api.cycle_type_prev, "cascade: cycle list type back")
  end
  map("n", "<leader>cr", api.renumber, "cascade: renumber")
  if on("rotate") then
    map("n", "<leader>cf", api.rotate_form_next, "cascade: rotate list form")
    map("x", "<leader>cf", api.rotate_form_next_visual, "cascade: rotate list form")
    map("n", "<leader>cF", api.rotate_form_prev, "cascade: rotate list form back")
    map("x", "<leader>cF", api.rotate_form_prev_visual, "cascade: rotate list form back")
  end
  if on("sort") then
    map("n", "<leader>cs", api.sort, "cascade: sort list A-Z")
    map("x", "<leader>cs", api.sort_visual, "cascade: sort list A-Z")
  end
  if on("reverse") then
    map("n", "<leader>cv", api.reverse, "cascade: reverse list order")
    map("x", "<leader>cv", api.reverse_visual, "cascade: reverse list order")
  end
  if on("strip") then
    -- Distinct from checkbox toggle (<leader>cx) to avoid a mapping clash.
    map("n", "<leader>cX", api.strip_checkbox, "cascade: strip checkboxes")
    map("x", "<leader>cX", api.strip_checkbox_visual, "cascade: strip checkboxes")
  end
end

--- Bind the global preset maps (word cycle + indent/move). The per-filetype
--- buffer-local list keys are attached by `cascade.bindings.autocmds`.
---@param cfg CascadeConfig
---@return nil
function M.bind_preset_globals(cfg)
  local api = require("cascade")
  local cyc_feat = cfg.cycle.features or {}
  if cfg.cycle.enable and cyc_feat.word ~= false then
    lib.map("n", "<C-y>", api.cycle_word_next, { silent = true, desc = "cascade: increment / cycle word" })
    lib.map("n", "<C-x>", api.cycle_word_prev, { silent = true, desc = "cascade: decrement / cycle word" })
    -- +/- fall back to their native "first non-blank of next/prev line" motion
    -- when the cursor isn't on a cyclable word or a number.
    lib.map("n", "+", api.increment, { silent = true, desc = "cascade: increment / cycle word" })
    lib.map("n", "-", api.decrement, { silent = true, desc = "cascade: decrement / cycle word" })
    lib.map("n", "<leader>cp", api.cycle_pick, { silent = true, desc = "cascade: pick a cycle-group value" })
  end

  -- Global indent/outdent (all filetypes): list-aware renumber on list lines,
  -- native shift everywhere else. Insert mode uses the native <C-t>/<C-d>.
  local list_feat = cfg.lists.features or {}
  if cfg.lists.enable and list_feat.indent ~= false then
    lib.map("n", "<A-Right>", api.indent, { silent = true, desc = "cascade: indent (+renumber)" })
    lib.map("x", "<A-Right>", api.indent_visual, { silent = true, desc = "cascade: indent (+renumber)" })
    lib.map("n", "<A-Left>", api.dedent, { silent = true, desc = "cascade: dedent (+renumber)" })
    lib.map("x", "<A-Left>", api.dedent_visual, { silent = true, desc = "cascade: dedent (+renumber)" })
    lib.map("i", "<A-Right>", "<C-t>", { silent = true, desc = "cascade: indent line (insert)" })
    lib.map("i", "<A-Left>", "<C-d>", { silent = true, desc = "cascade: dedent line (insert)" })
  end

  -- Global move-lines (all filetypes): reindent + renumber list blocks.
  if cfg.lists.enable and list_feat.move ~= false then
    lib.map("n", "<A-Up>", api.move_up, { silent = true, desc = "cascade: move line/selection up" })
    lib.map("x", "<A-Up>", api.move_up_visual, { silent = true, desc = "cascade: move line/selection up" })
    lib.map("n", "<A-Down>", api.move_down, { silent = true, desc = "cascade: move line/selection down" })
    lib.map("x", "<A-Down>", api.move_down_visual, { silent = true, desc = "cascade: move line/selection down" })
    lib.map("i", "<A-Up>", "<C-o>:m .-2<CR><C-o>==", { silent = true, desc = "cascade: move line up (insert)" })
    lib.map("i", "<A-Down>", "<C-o>:m .+1<CR><C-o>==", { silent = true, desc = "cascade: move line down (insert)" })
  end

  -- Global char transpose (all filetypes): swap with left/right neighbor.
  local trans_feat = cfg.transpose.features or {}
  if cfg.transpose.enable and trans_feat.char ~= false then
    lib.map("n", "<leader><Right>", api.swap_right, { silent = true, desc = "cascade: swap char with right neighbor" })
    lib.map("n", "<leader><Left>", api.swap_left, { silent = true, desc = "cascade: swap char with left neighbor" })
    lib.map(
      "x",
      "<leader><Right>",
      api.swap_right_visual,
      { silent = true, desc = "cascade: swap selection with right neighbor" }
    )
    lib.map("x", "<leader><Left>", api.swap_left_visual, { silent = true, desc = "cascade: swap selection with left neighbor" })
  end
end

return M

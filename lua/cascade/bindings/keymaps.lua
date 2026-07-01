---@module 'cascade.bindings.keymaps'
---@brief `<Plug>` mappings, the buffer-local list keys, and the preset globals.
---@description
--- Defining `<Plug>` mappings (always) decouples actions from concrete keys, so
--- users bind whatever they like without a wall of boilerplate. When
--- `keymaps.preset` is enabled the orchestrator also binds a small, sensible
--- default set: global word-cycle on `<C-a>`/`<C-x>`, global indent/move, and
--- buffer-local list keys (bound per filetype by `cascade.bindings.autocmds`).

local lib = require("cascade.util.lib")

local M = {}

--- The stable `<Plug>` surface. Mode is the mode each plug is defined in.
---@type { mode: string, lhs: string, action: string }[]
M.PLUGS = {
  { mode = "i", lhs = "<Plug>(cascade-cr)", action = "cr" },
  { mode = "n", lhs = "<Plug>(cascade-o)", action = "o" },
  { mode = "n", lhs = "<Plug>(cascade-O)", action = "O" },
  { mode = "n", lhs = "<Plug>(cascade-checkbox)", action = "toggle_checkbox" },
  { mode = "n", lhs = "<Plug>(cascade-cycle-type-next)", action = "cycle_type_next" },
  { mode = "n", lhs = "<Plug>(cascade-cycle-type-prev)", action = "cycle_type_prev" },
  { mode = "n", lhs = "<Plug>(cascade-cycle-word-next)", action = "cycle_word_next" },
  { mode = "n", lhs = "<Plug>(cascade-cycle-word-prev)", action = "cycle_word_prev" },
  { mode = "n", lhs = "<Plug>(cascade-indent)", action = "indent" },
  { mode = "x", lhs = "<Plug>(cascade-indent)", action = "indent_visual" },
  { mode = "n", lhs = "<Plug>(cascade-dedent)", action = "dedent" },
  { mode = "x", lhs = "<Plug>(cascade-dedent)", action = "dedent_visual" },
  { mode = "n", lhs = "<Plug>(cascade-renumber)", action = "renumber" },
  -- Block (normal) + selection (visual) transforms share a <Plug> name.
  { mode = "n", lhs = "<Plug>(cascade-rotate-form)", action = "rotate_form_next" },
  { mode = "x", lhs = "<Plug>(cascade-rotate-form)", action = "rotate_form_next_visual" },
  { mode = "n", lhs = "<Plug>(cascade-rotate-form-back)", action = "rotate_form_prev" },
  { mode = "x", lhs = "<Plug>(cascade-rotate-form-back)", action = "rotate_form_prev_visual" },
  { mode = "n", lhs = "<Plug>(cascade-sort)", action = "sort" },
  { mode = "x", lhs = "<Plug>(cascade-sort)", action = "sort_visual" },
  { mode = "n", lhs = "<Plug>(cascade-reverse)", action = "reverse" },
  { mode = "x", lhs = "<Plug>(cascade-reverse)", action = "reverse_visual" },
  { mode = "n", lhs = "<Plug>(cascade-strip-checkbox)", action = "strip_checkbox" },
  { mode = "x", lhs = "<Plug>(cascade-strip-checkbox)", action = "strip_checkbox_visual" },
  { mode = "n", lhs = "<Plug>(cascade-move-up)", action = "move_up" },
  { mode = "x", lhs = "<Plug>(cascade-move-up)", action = "move_up_visual" },
  { mode = "n", lhs = "<Plug>(cascade-move-down)", action = "move_down" },
  { mode = "x", lhs = "<Plug>(cascade-move-down)", action = "move_down_visual" },
}

--- Define every `<Plug>` mapping against the facade actions.
---@return nil
function M.define_plugs()
  local api = require("cascade")
  for i = 1, #M.PLUGS do
    local p = M.PLUGS[i]
    local fn = api[p.action]
    if type(fn) == "function" then
      lib.map(p.mode, p.lhs, fn, { silent = true, desc = "cascade: " .. p.action })
    end
  end
end

--- Bind buffer-local list keys for the current buffer (only enabled features).
--- Called from the FileType autocmd in `cascade.bindings.autocmds`.
---@return nil
function M.bind_list_buffer()
  local feat = require("cascade.config").get("lists").features or {}
  local function on(name)
    return feat[name] ~= false
  end
  local function map(modes, lhs, rhs, desc)
    lib.map(modes, lhs, rhs, { buffer = true, silent = true, desc = desc })
  end

  if on("continue") then
    map("i", "<CR>", "<Plug>(cascade-cr)", "cascade: continue list")
    map("n", "o", "<Plug>(cascade-o)", "cascade: open item below")
    map("n", "O", "<Plug>(cascade-O)", "cascade: open item above")
  end
  if on("checkbox") then
    map("n", "<leader>cx", "<Plug>(cascade-checkbox)", "cascade: toggle checkbox")
  end
  if on("cycle_type") then
    map("n", "<leader>ct", "<Plug>(cascade-cycle-type-next)", "cascade: cycle list type")
    map("n", "<leader>cT", "<Plug>(cascade-cycle-type-prev)", "cascade: cycle list type back")
  end
  map("n", "<leader>cr", "<Plug>(cascade-renumber)", "cascade: renumber")
  if on("rotate") then
    map({ "n", "x" }, "<leader>cf", "<Plug>(cascade-rotate-form)", "cascade: rotate list form")
    map({ "n", "x" }, "<leader>cF", "<Plug>(cascade-rotate-form-back)", "cascade: rotate list form back")
  end
  if on("sort") then
    map({ "n", "x" }, "<leader>cs", "<Plug>(cascade-sort)", "cascade: sort list A-Z")
  end
  if on("reverse") then
    map({ "n", "x" }, "<leader>cv", "<Plug>(cascade-reverse)", "cascade: reverse list order")
  end
  if on("strip") then
    -- Distinct from checkbox toggle (<leader>cx) to avoid a mapping clash.
    map({ "n", "x" }, "<leader>cX", "<Plug>(cascade-strip-checkbox)", "cascade: strip checkboxes")
  end
end

--- Bind the global preset maps (word cycle + indent/move). The per-filetype
--- buffer-local list keys are attached by `cascade.bindings.autocmds`.
---@param cfg CascadeConfig
---@return nil
function M.bind_preset_globals(cfg)
  local cyc_feat = cfg.cycle.features or {}
  if cfg.cycle.enable and cyc_feat.word ~= false then
    lib.map("n", "<C-a>", "<Plug>(cascade-cycle-word-next)", { silent = true, desc = "cascade: increment / cycle word" })
    lib.map("n", "<C-x>", "<Plug>(cascade-cycle-word-prev)", { silent = true, desc = "cascade: decrement / cycle word" })
  end

  -- Global indent/outdent (all filetypes): list-aware renumber on list lines,
  -- native shift everywhere else. Insert mode uses the native <C-t>/<C-d>.
  local list_feat = cfg.lists.features or {}
  if cfg.lists.enable and list_feat.indent ~= false then
    lib.map({ "n", "x" }, "<A-Right>", "<Plug>(cascade-indent)", { silent = true, desc = "cascade: indent (+renumber)" })
    lib.map({ "n", "x" }, "<A-Left>", "<Plug>(cascade-dedent)", { silent = true, desc = "cascade: dedent (+renumber)" })
    lib.map("i", "<A-Right>", "<C-t>", { silent = true, desc = "cascade: indent line (insert)" })
    lib.map("i", "<A-Left>", "<C-d>", { silent = true, desc = "cascade: dedent line (insert)" })
  end

  -- Global move-lines (all filetypes): reindent + renumber list blocks.
  if cfg.lists.enable and list_feat.move ~= false then
    lib.map({ "n", "x" }, "<A-Up>", "<Plug>(cascade-move-up)", { silent = true, desc = "cascade: move line/selection up" })
    lib.map({ "n", "x" }, "<A-Down>", "<Plug>(cascade-move-down)", { silent = true, desc = "cascade: move line/selection down" })
    lib.map("i", "<A-Up>", "<C-o>:m .-2<CR><C-o>==", { silent = true, desc = "cascade: move line up (insert)" })
    lib.map("i", "<A-Down>", "<C-o>:m .+1<CR><C-o>==", { silent = true, desc = "cascade: move line down (insert)" })
  end
end

return M

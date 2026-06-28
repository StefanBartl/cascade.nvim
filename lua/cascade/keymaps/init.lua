---@module 'cascade.keymaps'
---@brief `<Plug>` mappings and the optional opinionated preset binder.
---@description
--- Defining `<Plug>` mappings (always) decouples actions from concrete keys, so
--- users bind whatever they like without a wall of boilerplate. When
--- `keymaps.preset` is enabled we also bind a small, sensible default set:
--- global word-cycle on `<C-a>`/`<C-x>` and buffer-local list keys on the
--- configured filetypes.

local lib = require("cascade.util.lib")

local M = {}

--- The stable `<Plug>` surface. Mode is the mode each plug is defined in.
---@type { mode: string, lhs: string, action: string }[]
local PLUGS = {
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
}

--- Define every `<Plug>` mapping against the facade actions.
---@return nil
local function define_plugs()
  local api = require("cascade")
  for i = 1, #PLUGS do
    local p = PLUGS[i]
    local fn = api[p.action]
    if type(fn) == "function" then
      lib.map(p.mode, p.lhs, fn, { silent = true, desc = "cascade: " .. p.action })
    end
  end
end

--- Bind buffer-local list keys for the current buffer (only enabled features).
---@return nil
local function bind_list_buffer()
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
    map("n", "<leader>tc", "<Plug>(cascade-checkbox)", "cascade: toggle checkbox")
  end
  if on("cycle_type") then
    map("n", "<leader>tt", "<Plug>(cascade-cycle-type-next)", "cascade: cycle list type")
    map("n", "<leader>tT", "<Plug>(cascade-cycle-type-prev)", "cascade: cycle list type back")
  end
  map("n", "<leader>tr", "<Plug>(cascade-renumber)", "cascade: renumber")
  if on("rotate") then
    map({ "n", "x" }, "<leader>tf", "<Plug>(cascade-rotate-form)", "cascade: rotate list form")
    map({ "n", "x" }, "<leader>tF", "<Plug>(cascade-rotate-form-back)", "cascade: rotate list form back")
  end
  if on("sort") then
    map({ "n", "x" }, "<leader>ts", "<Plug>(cascade-sort)", "cascade: sort list A-Z")
  end
  if on("reverse") then
    map({ "n", "x" }, "<leader>tv", "<Plug>(cascade-reverse)", "cascade: reverse list order")
  end
  if on("strip") then
    map({ "n", "x" }, "<leader>tx", "<Plug>(cascade-strip-checkbox)", "cascade: strip checkboxes")
  end
end

--- Create the user commands (range-aware; work in normal and visual mode).
---@return nil
local function define_commands()
  local api = require("cascade")
  vim.api.nvim_create_user_command("CascadeRotate", function(cmd)
    local dir = (cmd.args == "prev" or cmd.bang) and -1 or 1
    api.run_command(api._transform.rotate, cmd, dir)
  end, {
    range = true,
    bang = true,
    nargs = "?",
    complete = function()
      return { "next", "prev" }
    end,
    desc = "cascade: rotate list form (range-aware; ! = backward)",
  })

  vim.api.nvim_create_user_command("CascadeSort", function(cmd)
    local dir = cmd.bang and -1 or 1 -- ! = descending (Z-A)
    api.run_command(api._transform.sort, cmd, dir)
  end, {
    range = true,
    bang = true,
    desc = "cascade: sort list A-Z (range-aware; ! = Z-A)",
  })

  vim.api.nvim_create_user_command("CascadeReverse", function(cmd)
    api.run_command(api._transform.reverse, cmd, 1)
  end, {
    range = true,
    desc = "cascade: reverse list order (range-aware)",
  })

  vim.api.nvim_create_user_command("CascadeStrip", function(cmd)
    api.run_command(api._transform.strip, cmd, 1)
  end, {
    range = true,
    desc = "cascade: strip checkboxes (range-aware)",
  })

  vim.api.nvim_create_user_command("CascadeIndent", function(cmd)
    api.run_indent_command(cmd, 1)
  end, {
    range = true,
    nargs = "?",
    desc = "cascade: indent line/range (+renumber; arg = levels)",
  })

  vim.api.nvim_create_user_command("CascadeDedent", function(cmd)
    api.run_indent_command(cmd, -1)
  end, {
    range = true,
    nargs = "?",
    desc = "cascade: dedent line/range (+renumber; arg = levels)",
  })
end

--- Bind the preset key set (global cycle + per-filetype list maps).
---@param cfg CascadeConfig
---@return nil
local function bind_preset(cfg)
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

  if cfg.lists.enable and type(cfg.lists.filetypes) == "table" and #cfg.lists.filetypes > 0 then
    local group = lib.augroup("cascade_lists")
    vim.api.nvim_create_autocmd("FileType", {
      group = group,
      pattern = cfg.lists.filetypes,
      callback = bind_list_buffer,
      desc = "cascade: bind list keymaps",
    })
    -- Cover buffers already open at setup time.
    local cur_ft = vim.bo.filetype
    for i = 1, #cfg.lists.filetypes do
      if cfg.lists.filetypes[i] == cur_ft then
        bind_list_buffer()
        break
      end
    end
  end
end

--- Define plug maps and, if requested, the preset.
---@param cfg CascadeConfig
---@return nil
function M.setup(cfg)
  define_plugs()
  define_commands()
  if cfg.keymaps and cfg.keymaps.preset then
    bind_preset(cfg)
  end
end

return M

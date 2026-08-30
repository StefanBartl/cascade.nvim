---@module 'cascade.bindings.keymaps'
--- The buffer-local list keys and the preset globals.
---
--- Two surfaces, declared separately because they are bound at different
--- times: the list keys exist only inside a buffer whose filetype matched,
--- the globals apply everywhere. `lib.nvim.bindings.keymap` records them as
--- `cascade` and `cascade/list`; both label themselves "cascade:" in
--- which-key, since a user reading a popup does not care that the plugin
--- splits its keymaps internally.
---
--- Every key used to be hard-coded here, with only the feature switches
--- (`lists.features.*`, `cycle.features.*`, …) deciding whether a whole group
--- was bound. Declaring them as named actions makes each one individually
--- overridable -- `keymaps = { toggle_checkbox = "<leader>x" }` moves one,
--- `= false` drops one -- while the feature switches keep working: a
--- switched-off feature forces its own keys to `false`.
---
--- Maps go straight onto the facade actions in `cascade` — no `<Plug>`
--- indirection. which-key needs no registration for the individual keys; it
--- reads them from each mapping's own `desc`.

local keymap = require("lib.nvim.bindings.keymap")

local M = {}

---@internal
--- Turn every key of a switched-off feature into `false`, on a copy.
---
--- Writing into the live config would make a feature switch indistinguishable
--- from a per-key opt-out on the next read.
---@param user table
---@param families table<string, string[]>
---@param off table<string, boolean>  # family -> true when switched off
---@return table
local function apply_families(user, families, off)
  local out = vim.deepcopy(user or {})
  for family, names in pairs(families) do
    if off[family] then
      for _, name in ipairs(names) do
        out[name] = false
      end
    end
  end
  return out
end

--- The buffer-local list keys, by feature family.
---@type table<string, string[]>
local LIST_FAMILIES = {
  continue = { "continue", "continue_literal", "open_below", "open_above" },
  checkbox = { "toggle_checkbox" },
  bullet_toggle = { "bullet_toggle", "star_toggle" },
  number_toggle = { "number_toggle" },
  checkbox_toggle = { "checkbox_toggle" },
  cycle_type = { "cycle_type_next", "cycle_type_prev" },
  rotate = { "rotate_form_next", "rotate_form_prev" },
  sort = { "sort" },
  reverse = { "reverse" },
  strip = { "strip_checkbox" },
}

--- Bind buffer-local list keys for the current buffer (only enabled features).
--- Called from the FileType autocmd in `cascade.bindings.autocmds`.
---@return Lib.Keymap.Registered[]
function M.bind_list_buffer()
  local api = require("cascade")
  local config = require("cascade.config")
  local lists = config.get("lists") or {}
  local feat = lists.features or {}
  local user = (config.get("keymaps") or {}).list or {}

  ---@type Lib.Keymap.Spec
  local spec = {
    prefix = "<leader>c",
    which_key = { group = "cascade" },
    order = {
      "continue",
      "continue_literal",
      "open_below",
      "open_above",
      "toggle_checkbox",
      "bullet_toggle",
      "star_toggle",
      "number_toggle",
      "checkbox_toggle",
      "cycle_type_next",
      "cycle_type_prev",
      "renumber",
      "rotate_form_next",
      "rotate_form_prev",
      "sort",
      "reverse",
      "strip_checkbox",
    },
    actions = {
      continue = { default = "<CR>", mode = "i", rhs = api.cr, desc = "continue list" },
      continue_literal = {
        default = "<M-CR>",
        mode = "i",
        rhs = api.cr_literal,
        desc = "plain newline (skip list continuation)",
      },
      open_below = { default = "o", rhs = api.o, desc = "open item below" },
      open_above = { default = "O", rhs = api.O, desc = "open item above" },

      toggle_checkbox = {
        default = "<leader>cx",
        rhs = api.toggle_checkbox,
        desc = "toggle checkbox",
      },

      bullet_toggle = {
        default = "<A-->",
        desc = "toggle bullet point",
        binds = {
          { mode = "n", rhs = api.bullet_toggle },
          { mode = "x", rhs = api.bullet_toggle_visual },
        },
      },
      star_toggle = {
        default = "<A-*>",
        desc = "toggle star bullet",
        binds = {
          { mode = "n", rhs = api.star_toggle },
          { mode = "x", rhs = api.star_toggle_visual },
        },
      },
      number_toggle = {
        default = "<A-0>",
        desc = "toggle numbered list",
        binds = {
          { mode = "n", rhs = api.number_toggle },
          { mode = "x", rhs = api.number_toggle_visual },
        },
      },
      checkbox_toggle = {
        default = "<A-c>",
        desc = "toggle checkbox bullet",
        binds = {
          { mode = "n", rhs = api.checkbox_toggle },
          { mode = "x", rhs = api.checkbox_toggle_visual },
        },
      },

      cycle_type_next = {
        default = "<leader>ct",
        rhs = api.cycle_type_next,
        desc = "cycle list type",
      },
      cycle_type_prev = {
        default = "<leader>cT",
        rhs = api.cycle_type_prev,
        desc = "cycle list type back",
      },

      -- No feature switch of its own: renumbering is what every other list
      -- action leans on, so it is always available inside a list buffer.
      renumber = { default = "<leader>cr", rhs = api.renumber, desc = "renumber" },

      rotate_form_next = {
        default = "<leader>cf",
        desc = "rotate list form",
        binds = {
          { mode = "n", rhs = api.rotate_form_next },
          { mode = "x", rhs = api.rotate_form_next_visual },
        },
      },
      rotate_form_prev = {
        default = "<leader>cF",
        desc = "rotate list form back",
        binds = {
          { mode = "n", rhs = api.rotate_form_prev },
          { mode = "x", rhs = api.rotate_form_prev_visual },
        },
      },

      sort = {
        default = "<leader>cs",
        desc = "sort list A-Z",
        binds = { { mode = "n", rhs = api.sort }, { mode = "x", rhs = api.sort_visual } },
      },
      reverse = {
        default = "<leader>cv",
        desc = "reverse list order",
        binds = { { mode = "n", rhs = api.reverse }, { mode = "x", rhs = api.reverse_visual } },
      },

      -- Distinct from toggle_checkbox (<leader>cx) to avoid a mapping clash.
      strip_checkbox = {
        default = "<leader>cX",
        desc = "strip checkboxes",
        binds = {
          { mode = "n", rhs = api.strip_checkbox },
          { mode = "x", rhs = api.strip_checkbox_visual },
        },
      },
    },
  }

  local off = {}
  for family in pairs(LIST_FAMILIES) do
    off[family] = feat[family] == false
  end

  return keymap.register("cascade", spec, apply_families(user, LIST_FAMILIES, off), { buffer = true, surface = "list" })
end

--- The global keys, by feature family.
---@type table<string, string[]>
local GLOBAL_FAMILIES = {
  cycle_word = { "cycle_word_next", "cycle_word_prev", "increment", "decrement", "cycle_pick" },
  cycle_char = { "cycle_char_next", "cycle_char_prev" },
  sequence = { "renumber_selection" },
  indent = { "indent", "dedent", "indent_insert", "dedent_insert", "indent_levels", "dedent_levels" },
  move = { "move_up", "move_down", "move_up_insert", "move_down_insert" },
  transpose_char = { "swap_right", "swap_left" },
  transpose_word = { "swap_word_right", "swap_word_left" },
}

--- Bind the global preset maps (word cycle + indent/move/transpose). The
--- per-filetype buffer-local list keys are attached by `cascade.bindings.autocmds`.
---@param cfg CascadeConfig
---@return Lib.Keymap.Registered[]
function M.bind_preset_globals(cfg)
  local api = require("cascade")
  local user = (cfg.keymaps or {}).globals or {}

  ---@type Lib.Keymap.Spec
  local spec = {
    prefix = "<leader>c",
    which_key = { group = "cascade" },
    order = {
      "cycle_word_next",
      "cycle_word_prev",
      "increment",
      "decrement",
      "cycle_pick",
      "cycle_char_next",
      "cycle_char_prev",
      "renumber_selection",
      "indent",
      "dedent",
      "indent_insert",
      "dedent_insert",
      "indent_levels",
      "dedent_levels",
      "move_up",
      "move_down",
      "move_up_insert",
      "move_down_insert",
      "swap_right",
      "swap_left",
      "swap_word_right",
      "swap_word_left",
    },
    actions = {
      cycle_word_next = {
        default = "<C-y>",
        rhs = api.cycle_word_next,
        desc = "increment / cycle word",
      },
      cycle_word_prev = {
        default = "<C-x>",
        rhs = api.cycle_word_prev,
        desc = "decrement / cycle word",
      },
      -- +/- fall back to their native "first non-blank of next/prev line"
      -- motion when the cursor isn't on a cyclable word or a number.
      increment = { default = "+", rhs = api.increment, desc = "increment / cycle word" },
      decrement = { default = "-", rhs = api.decrement, desc = "decrement / cycle word" },
      cycle_pick = {
        default = "<leader>cp",
        rhs = api.cycle_pick,
        desc = "pick a cycle-group value",
      },

      -- The modifier-heavy siblings of <C-y>/<C-x>: same direction, but the
      -- single character under the cursor rather than the whole token, so a
      -- letter inside a word is reachable.
      --
      -- Two keys each, not one. Ctrl+Alt+<letter> reaches Neovim as ESC plus
      -- the letter's control byte (|:map-alt-keys|), which is about as
      -- portable as a modified key gets -- but "about" is not "always": a
      -- terminal with "Alt sends Escape" switched off drops it, and on a
      -- German layout AltGr *is* Ctrl+Alt, so a combination that happens to
      -- carry a third-level character (AltGr+q = @) never arrives as a key
      -- at all. None of that is detectable from inside Neovim -- feedkeys
      -- enters below the terminal decoder, so a self-test would pass on a
      -- terminal that cannot send the key. Binding the leader alias too costs
      -- one key and removes the question.
      cycle_char_next = {
        default = { "<C-M-y>", "<leader>cy" },
        rhs = api.cycle_char_next,
        desc = "cycle char under cursor (in-word)",
      },
      cycle_char_prev = {
        default = { "<C-M-x>", "<leader>cY" },
        rhs = api.cycle_char_prev,
        desc = "cycle char under cursor back (in-word)",
      },

      -- Visual mode only, on purpose: an Ex-command range (`:'<,'>`) is always
      -- linewise in Vim and would discard the columns a mid-line charwise
      -- selection needs. Capital R sets it apart from <leader>cr (renumber the
      -- whole list block at the cursor).
      renumber_selection = {
        default = "<leader>cR",
        mode = "x",
        rhs = api.renumber_selection,
        desc = "renumber the numbers inside the selection",
      },

      indent = {
        default = "<A-Right>",
        binds = {
          { mode = "n", rhs = api.indent, desc = "indent (Ncount = N lines, +renumber)" },
          { mode = "x", rhs = api.indent_visual, desc = "indent (+renumber)" },
        },
      },
      dedent = {
        default = "<A-Left>",
        binds = {
          { mode = "n", rhs = api.dedent, desc = "dedent (Ncount = N lines, +renumber)" },
          { mode = "x", rhs = api.dedent_visual, desc = "dedent (+renumber)" },
        },
      },
      indent_insert = {
        default = "<A-Right>",
        mode = "i",
        rhs = "<C-t>",
        desc = "indent line (insert)",
      },
      dedent_insert = {
        default = "<A-Left>",
        mode = "i",
        rhs = "<C-d>",
        desc = "dedent line (insert)",
      },
      -- The old count semantics of <A-Right>/<A-Left> (Ncount = N levels on
      -- one line), moved behind <leader> once the bare keys' count came to
      -- mean "N lines".
      indent_levels = {
        default = "<leader><A-Right>",
        rhs = api.indent_levels,
        desc = "indent (Ncount = N levels, +renumber)",
      },
      dedent_levels = {
        default = "<leader><A-Left>",
        rhs = api.dedent_levels,
        desc = "dedent (Ncount = N levels, +renumber)",
      },

      move_up = {
        default = "<A-Up>",
        desc = "move line/selection up",
        binds = { { mode = "n", rhs = api.move_up }, { mode = "x", rhs = api.move_up_visual } },
      },
      move_down = {
        default = "<A-Down>",
        desc = "move line/selection down",
        binds = {
          { mode = "n", rhs = api.move_down },
          { mode = "x", rhs = api.move_down_visual },
        },
      },
      move_up_insert = {
        default = "<A-Up>",
        mode = "i",
        rhs = "<C-o>:m .-2<CR><C-o>==",
        desc = "move line up (insert)",
      },
      move_down_insert = {
        default = "<A-Down>",
        mode = "i",
        rhs = "<C-o>:m .+1<CR><C-o>==",
        desc = "move line down (insert)",
      },

      swap_right = {
        default = "<leader><Right>",
        binds = {
          {
            mode = "n",
            rhs = api.swap_right,
            desc = "swap char with right neighbor (Ncount = N times)",
          },
          {
            mode = "x",
            rhs = api.swap_right_visual,
            desc = "swap selection with right neighbor (Ncount = N times)",
          },
        },
      },
      swap_left = {
        default = "<leader><Left>",
        binds = {
          {
            mode = "n",
            rhs = api.swap_left,
            desc = "swap char with left neighbor (Ncount = N times)",
          },
          {
            mode = "x",
            rhs = api.swap_left_visual,
            desc = "swap selection with left neighbor (Ncount = N times)",
          },
        },
      },
      swap_word_right = {
        default = "<leader><C-Right>",
        binds = {
          {
            mode = "n",
            rhs = api.swap_word_right,
            desc = "swap word with right neighbor word (Ncount = N times)",
          },
          {
            mode = "x",
            rhs = api.swap_word_right_visual,
            desc = "swap selection with right neighbor word (Ncount = N times)",
          },
        },
      },
      swap_word_left = {
        default = "<leader><C-Left>",
        binds = {
          {
            mode = "n",
            rhs = api.swap_word_left,
            desc = "swap word with left neighbor word (Ncount = N times)",
          },
          {
            mode = "x",
            rhs = api.swap_word_left_visual,
            desc = "swap selection with left neighbor word (Ncount = N times)",
          },
        },
      },
    },
  }

  local seq = cfg.sequence
  local list_feat = (cfg.lists or {}).features or {}
  local cyc_feat = (cfg.cycle or {}).features or {}
  local trans_feat = (cfg.transpose or {}).features or {}

  local off = {
    cycle_word = not (cfg.cycle and cfg.cycle.enable and cyc_feat.word ~= false),
    cycle_char = not (cfg.cycle and cfg.cycle.enable and cyc_feat.char ~= false),
    sequence = type(seq) == "table" and seq.enable == false,
    indent = not (cfg.lists and cfg.lists.enable and list_feat.indent ~= false),
    move = not (cfg.lists and cfg.lists.enable and list_feat.move ~= false),
    transpose_char = not (cfg.transpose and cfg.transpose.enable and trans_feat.char ~= false),
    transpose_word = not (cfg.transpose and cfg.transpose.enable and trans_feat.word ~= false),
  }

  return keymap.register("cascade", spec, apply_families(user, GLOBAL_FAMILIES, off))
end

return M

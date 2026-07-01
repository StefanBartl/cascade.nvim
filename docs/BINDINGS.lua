-- docs/BINDINGS.lua — cascade.nvim binding cheatsheet.
--
-- A single, machine-readable overview of every keymap, user command and
-- autocommand cascade defines. This file is DOCUMENTATION only: it is not
-- required at runtime. It mirrors the source of truth in
-- `lua/cascade/bindings/`. If you add or rename a binding there, update the
-- matching entry here.
--
-- Structure:
--   plug        — the stable <Plug> surface (always defined by setup()).
--   preset      — keys bound only when `keymaps.preset = true`.
--                   .global — bound for every filetype.
--                   .buffer — buffer-local, bound per `lists.filetypes`.
--   commands    — the `:Cascade*` user commands (always defined).
--   autocmds    — autocommands registered by setup().
--
-- `feature` fields refer to `lists.features.*` / `cycle.features.*` toggles:
-- disabling a feature drops its preset key(s) and no-ops its action.

return {
  plug = {
    { lhs = "<Plug>(cascade-cr)",               mode = "i",      action = "cr",               desc = "Continue list / delete empty bullet" },
    { lhs = "<Plug>(cascade-o)",                mode = "n",      action = "o",                desc = "Open item below" },
    { lhs = "<Plug>(cascade-O)",                mode = "n",      action = "O",                desc = "Open item above" },
    { lhs = "<Plug>(cascade-checkbox)",         mode = "n",      action = "toggle_checkbox",  desc = "Toggle/cycle checkbox" },
    { lhs = "<Plug>(cascade-cycle-type-next)",  mode = "n",      action = "cycle_type_next",  desc = "List marker type forward" },
    { lhs = "<Plug>(cascade-cycle-type-prev)",  mode = "n",      action = "cycle_type_prev",  desc = "List marker type backward" },
    { lhs = "<Plug>(cascade-cycle-word-next)",  mode = "n",      action = "cycle_word_next",  desc = "Word/number forward (native <C-a> fallback)" },
    { lhs = "<Plug>(cascade-cycle-word-prev)",  mode = "n",      action = "cycle_word_prev",  desc = "Word/number backward (native <C-x> fallback)" },
    { lhs = "<Plug>(cascade-indent)",           mode = { "n", "x" }, action = "indent",       desc = "Indent + level-aware renumber" },
    { lhs = "<Plug>(cascade-dedent)",           mode = { "n", "x" }, action = "dedent",       desc = "Dedent + level-aware renumber" },
    { lhs = "<Plug>(cascade-renumber)",         mode = "n",      action = "renumber",         desc = "Renumber the block at the cursor" },
    { lhs = "<Plug>(cascade-rotate-form)",      mode = { "n", "x" }, action = "rotate_form_next", desc = "Rotate block/selection through forms" },
    { lhs = "<Plug>(cascade-rotate-form-back)", mode = { "n", "x" }, action = "rotate_form_prev", desc = "Rotate forms backward" },
    { lhs = "<Plug>(cascade-sort)",             mode = { "n", "x" }, action = "sort",         desc = "Sort block/selection A-Z" },
    { lhs = "<Plug>(cascade-reverse)",          mode = { "n", "x" }, action = "reverse",      desc = "Reverse block/selection order" },
    { lhs = "<Plug>(cascade-strip-checkbox)",   mode = { "n", "x" }, action = "strip_checkbox", desc = "Strip checkboxes (markers stay)" },
    { lhs = "<Plug>(cascade-move-up)",          mode = { "n", "x" }, action = "move_up",      desc = "Move line/selection up + renumber" },
    { lhs = "<Plug>(cascade-move-down)",        mode = { "n", "x" }, action = "move_down",    desc = "Move line/selection down + renumber" },
  },

  preset = {
    global = {
      { lhs = "<C-a>",     mode = "n",          rhs = "<Plug>(cascade-cycle-word-next)", feature = "cycle.word",  desc = "Increment / cycle word" },
      { lhs = "<C-x>",     mode = "n",          rhs = "<Plug>(cascade-cycle-word-prev)", feature = "cycle.word",  desc = "Decrement / cycle word" },
      { lhs = "<A-Right>", mode = { "n", "x" }, rhs = "<Plug>(cascade-indent)",          feature = "lists.indent", desc = "Indent (+renumber)" },
      { lhs = "<A-Left>",  mode = { "n", "x" }, rhs = "<Plug>(cascade-dedent)",          feature = "lists.indent", desc = "Dedent (+renumber)" },
      { lhs = "<A-Right>", mode = "i",          rhs = "<C-t>",                           feature = "lists.indent", desc = "Indent line (insert)" },
      { lhs = "<A-Left>",  mode = "i",          rhs = "<C-d>",                           feature = "lists.indent", desc = "Dedent line (insert)" },
      { lhs = "<A-Up>",    mode = { "n", "x" }, rhs = "<Plug>(cascade-move-up)",         feature = "lists.move",  desc = "Move line/selection up" },
      { lhs = "<A-Down>",  mode = { "n", "x" }, rhs = "<Plug>(cascade-move-down)",       feature = "lists.move",  desc = "Move line/selection down" },
      { lhs = "<A-Up>",    mode = "i",          rhs = "<C-o>:m .-2<CR><C-o>==",          feature = "lists.move",  desc = "Move line up (insert)" },
      { lhs = "<A-Down>",  mode = "i",          rhs = "<C-o>:m .+1<CR><C-o>==",          feature = "lists.move",  desc = "Move line down (insert)" },
    },

    buffer = {
      { lhs = "<CR>",        mode = "i",          rhs = "<Plug>(cascade-cr)",              feature = "continue",   desc = "Continue list" },
      { lhs = "o",           mode = "n",          rhs = "<Plug>(cascade-o)",               feature = "continue",   desc = "Open item below" },
      { lhs = "O",           mode = "n",          rhs = "<Plug>(cascade-O)",               feature = "continue",   desc = "Open item above" },
      { lhs = "<leader>cx",  mode = "n",          rhs = "<Plug>(cascade-checkbox)",        feature = "checkbox",   desc = "Toggle checkbox" },
      { lhs = "<leader>ct",  mode = "n",          rhs = "<Plug>(cascade-cycle-type-next)", feature = "cycle_type", desc = "Cycle list type" },
      { lhs = "<leader>cT",  mode = "n",          rhs = "<Plug>(cascade-cycle-type-prev)", feature = "cycle_type", desc = "Cycle list type back" },
      { lhs = "<leader>cr",  mode = "n",          rhs = "<Plug>(cascade-renumber)",        feature = nil,          desc = "Renumber" },
      { lhs = "<leader>cf",  mode = { "n", "x" }, rhs = "<Plug>(cascade-rotate-form)",     feature = "rotate",     desc = "Rotate list form" },
      { lhs = "<leader>cF",  mode = { "n", "x" }, rhs = "<Plug>(cascade-rotate-form-back)", feature = "rotate",    desc = "Rotate list form back" },
      { lhs = "<leader>cs",  mode = { "n", "x" }, rhs = "<Plug>(cascade-sort)",            feature = "sort",       desc = "Sort list A-Z" },
      { lhs = "<leader>cv",  mode = { "n", "x" }, rhs = "<Plug>(cascade-reverse)",         feature = "reverse",    desc = "Reverse list order" },
      { lhs = "<leader>cX",  mode = { "n", "x" }, rhs = "<Plug>(cascade-strip-checkbox)",  feature = "strip",      desc = "Strip checkboxes" },
    },
  },

  commands = {
    { name = "CascadeRotate",  args = "[next|prev]", bang = true, range = true, desc = "Rotate list form (range-aware; ! = backward)" },
    { name = "CascadeSort",    args = nil,           bang = true, range = true, desc = "Sort list A-Z (range-aware; ! = Z-A)" },
    { name = "CascadeReverse", args = nil,           bang = false, range = true, desc = "Reverse list order (range-aware)" },
    { name = "CascadeStrip",   args = nil,           bang = false, range = true, desc = "Strip checkboxes (range-aware)" },
    { name = "CascadeIndent",  args = "[n]",         bang = false, range = true, desc = "Indent line/range (+renumber; arg = levels)" },
    { name = "CascadeDedent",  args = "[n]",         bang = false, range = true, desc = "Dedent line/range (+renumber; arg = levels)" },
  },

  autocmds = {
    { event = "FileType",    group = "cascade_list_keymaps",  pattern = "lists.filetypes", when = "keymaps.preset = true",  desc = "Bind buffer-local list keymaps" },
    { event = "BufWritePre", group = "cascade_renumber_save", pattern = "*",               when = "\"save\" in lists.renumber.on", desc = "Renumber ordered lists on save" },
  },
}

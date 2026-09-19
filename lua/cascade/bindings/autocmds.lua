---@module 'cascade.bindings.autocmds'
--- Autocommands: per-filetype list keymaps, hanging-indent options, and
--- the save-time renumber.
---
--- Four autocmds, all idempotent (their augroups are cleared on every setup):
---   - a FileType autocmd that binds the buffer-local list keys on the
---     configured `lists.filetypes` (only when the preset is enabled);
---   - a FileType autocmd that applies the hanging-indent `formatlistpat`/
---     `formatoptions` on the same filetypes (independent of the keymap
---     preset — it's a `lists` behavior, not a keymap one);
---   - a BufWritePre autocmd that renumbers ordered lists on save (only when
---     "save" is a configured `lists.renumber.on` trigger);
---   - a FileType autocmd on the strings domain's filetypes that binds the
---     buffer-local `strings.on` triggers (InsertLeave/TextChanged by
---     default) running `cascade.strings.convert` one tick deferred.

local config = require("cascade.config")
local Context = require("cascade.core.context")
local renumber = require("cascade.lists.renumber")
local format = require("cascade.lists.format")
local autocmd = require("lib.nvim.bindings.autocmd")
local lib = require("cascade.util.lib")

local M = {}

---@internal
--- Whether `ft` is in `fts` (nil `fts` means "every filetype").
---@param fts string[]|nil
---@param ft string
---@return boolean
local function ft_in(fts, ft)
  if fts == nil then
    return true
  end
  for i = 1, #fts do
    if fts[i] == ft then
      return true
    end
  end
  return false
end

---@internal
--- Bind the buffer-local list keys per filetype (preset only). The augroup
--- is cleared unconditionally, before either gate: a re-`setup()` that turns
--- the preset (or `lists.enable`/`lists.filetypes`) off must still drop the
--- previous run's autocmd, not just skip creating a new one (LUA-87). Called
--- unconditionally from `M.setup` for exactly this reason -- the preset
--- check used to live at that call site instead, which bypassed this
--- function (and its `lib.augroup` clear) entirely when the preset was off.
---@param cfg CascadeConfig
---@return nil
local function setup_list_keymaps(cfg)
  local group = lib.augroup("cascade_list_keymaps")
  if not (cfg.keymaps and cfg.keymaps.preset) then
    return
  end
  if not (cfg.lists.enable and type(cfg.lists.filetypes) == "table" and #cfg.lists.filetypes > 0) then
    return
  end
  local keymaps = require("cascade.bindings.keymaps")
  autocmd.create("FileType", keymaps.bind_list_buffer, {
    group = group,
    pattern = cfg.lists.filetypes,
    desc = "cascade: bind list keymaps",
  })
  -- Cover buffers already open at setup time.
  local cur_ft = vim.bo.filetype
  for i = 1, #cfg.lists.filetypes do
    if cfg.lists.filetypes[i] == cur_ft then
      keymaps.bind_list_buffer()
      break
    end
  end
end

--- Apply the hanging-indent `formatlistpat`/`formatoptions` per filetype.
--- Independent of the keymap preset: it's a `lists` behavior (gated by
--- `lists.continue.hanging_indent`), not a keymap one. The augroup is
--- cleared unconditionally, before the gate -- see `setup_list_keymaps`
--- (LUA-87).
---@internal
---@param cfg CascadeConfig
---@return nil
local function setup_hanging_indent(cfg)
  local group = lib.augroup("cascade_list_format")
  if not (cfg.lists.enable and type(cfg.lists.filetypes) == "table" and #cfg.lists.filetypes > 0) then
    return
  end
  autocmd.create("FileType", function(args)
    format.apply(args.buf, config.get("lists"))
  end, {
    group = group,
    pattern = cfg.lists.filetypes,
    desc = "cascade: hanging-indent formatlistpat",
  })
  -- Cover buffers already open at setup time.
  local cur_ft = vim.bo.filetype
  for i = 1, #cfg.lists.filetypes do
    if cfg.lists.filetypes[i] == cur_ft then
      format.apply(0, cfg.lists)
      break
    end
  end
end

---@internal
--- Register the BufWritePre renumber autocmd when "save" is a configured
--- trigger. Idempotent: the augroup is cleared on every setup() call.
---@return nil
local function setup_save_renumber()
  local group = lib.augroup("cascade_renumber_save")
  local lists = config.get("lists")
  if not (lists.enable and renumber.at(lists, "save")) then
    return
  end
  autocmd.create("BufWritePre", function(args)
    local opts = config.get("lists")
    if not (opts.enable and renumber.at(opts, "save")) then
      return
    end
    if not Context.writable(args.buf) or not ft_in(opts.filetypes, vim.bo[args.buf].filetype) then
      return
    end
    pcall(renumber.all, args.buf, opts)
  end, {
    group = group,
    pattern = "*",
    desc = "cascade: renumber lists on save",
  })
end

---@internal
--- Buffers already given the strings domain's per-buffer triggers this
--- setup() cycle, and their debounce handle. Reset at the top of
--- setup_strings(), in the same place the shared `triggers` augroup below
--- is cleared, so the two never go out of sync -- a stale `true` left over
--- after a re-setup() would silently skip re-registering a buffer whose
--- actual autocmd that group-level clear just wiped out.
---@type table<integer, true>
local strings_attached = {}
---@type table<integer, Lib.Debounce.Handle>
local strings_debounced = {}

---@internal
--- Bind the strings domain's buffer-local triggers on `bufnr`, into the
--- shared `group` (created ONCE per setup() cycle by setup_strings() and
--- passed in here, rather than looked up per buffer -- `lib.augroup()`
--- clears its group on every call, so calling it once per buffer would
--- wipe every OTHER already-attached buffer's registration each time a new
--- one is attached; a single, shared, buffer-scoped group is what keeps
--- this bounded instead of minting one augroup per buffer forever).
---
--- The actual conversion runs through a per-buffer debounce (`ms = 1`,
--- matching the idea's origin's "deferred one tick, so other autocmds on
--- the same event finish first") rather than a bare `vim.defer_fn`: a
--- burst of qualifying events (a macro, several edits in quick
--- succession) used to schedule one independent timer each, all of them
--- firing and each redoing a full Tree-sitter parse -- the debounce
--- collapses a burst into a single attempt, using the most recent
--- trigger's window.
---@param bufnr integer
---@param group integer
---@return nil
local function bind_strings_buffer(bufnr, group)
  if strings_attached[bufnr] then
    return
  end
  local strings = require("cascade.strings")
  local on = config.get("strings.on")
  if type(on) ~= "table" or #on == 0 then
    return
  end
  strings_attached[bufnr] = true

  local function forget()
    strings_attached[bufnr] = nil
    local handle = strings_debounced[bufnr]
    if handle then
      pcall(handle.cancel)
      strings_debounced[bufnr] = nil
    end
  end

  vim.api.nvim_create_autocmd(on, {
    group = group,
    buffer = bufnr,
    desc = "cascade: convert the string literal at the cursor",
    callback = function(args)
      if not vim.api.nvim_buf_is_valid(args.buf) then
        forget()
        return true
      end
      -- The buffer changed filetype away from the domain: drop the trigger.
      if not strings.converter_for(vim.bo[args.buf].filetype) then
        forget()
        return true
      end
      -- Captured synchronously, at the moment the triggering event fires --
      -- NOT rediscovered when the debounce eventually runs, by which point
      -- the current window may have changed, and `vim.fn.bufwinid` would
      -- only ever return the FIRST window showing this buffer, not
      -- necessarily the one that was just edited.
      local trigger_win = vim.api.nvim_get_current_win()
      local handle = strings_debounced[args.buf]
      if not handle then
        handle = require("lib.nvim.debounce").new(function(win)
          if vim.api.nvim_buf_is_valid(args.buf) then
            strings.convert(args.buf, win)
          end
        end, 1)
        strings_debounced[args.buf] = handle
      end
      handle.call(trigger_win)
    end,
  })
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = group,
    buffer = bufnr,
    once = true,
    desc = "cascade: forget the strings domain's per-buffer state",
    callback = forget,
  })
end

---@internal
--- Register the strings domain's FileType trigger on its filetypes.
---@return nil
local function setup_strings()
  local group = lib.augroup("cascade_strings")
  local triggers_group = lib.augroup("cascade_strings_triggers")
  for bufnr in pairs(strings_attached) do
    local handle = strings_debounced[bufnr]
    if handle then
      pcall(handle.cancel)
    end
  end
  strings_attached = {}
  strings_debounced = {}
  local strings = require("cascade.strings")
  local fts = strings.filetypes()
  if #fts == 0 then
    return
  end
  autocmd.create("FileType", function(args)
    bind_strings_buffer(args.buf, triggers_group)
  end, {
    group = group,
    pattern = fts,
    desc = "cascade: bind the strings domain's triggers",
  })
  -- Cover the buffer already open at setup time.
  if ft_in(fts, vim.bo.filetype) then
    bind_strings_buffer(vim.api.nvim_get_current_buf(), triggers_group)
  end
end

--- Register cascade's autocmds.
---@param cfg CascadeConfig
---@return nil
function M.setup(cfg)
  -- Unconditional: setup_list_keymaps clears its own augroup before checking
  -- the preset gate itself (LUA-87) -- gating the call here instead would
  -- bypass that clear entirely whenever the preset is off.
  setup_list_keymaps(cfg)
  setup_hanging_indent(cfg)
  setup_save_renumber()
  setup_strings()
end

return M

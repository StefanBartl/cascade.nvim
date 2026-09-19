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
--- Bind the strings domain's buffer-local triggers on `bufnr`. Deferred one
--- tick, like the idea's origin, so other autocmds on the same event finish
--- before the buffer is rewritten under them.
---@param bufnr integer
---@return nil
local function bind_strings_buffer(bufnr)
  local strings = require("cascade.strings")
  local on = config.get("strings.on")
  if type(on) ~= "table" or #on == 0 then
    return
  end
  local group = vim.api.nvim_create_augroup(("cascade_strings_%d"):format(bufnr), { clear = true })
  vim.api.nvim_create_autocmd(on, {
    group = group,
    buffer = bufnr,
    desc = "cascade: convert the string literal at the cursor",
    callback = function(args)
      if not vim.api.nvim_buf_is_valid(args.buf) then
        return true
      end
      -- The buffer changed filetype away from the domain: drop the trigger.
      if not strings.converter_for(vim.bo[args.buf].filetype) then
        return true
      end
      vim.defer_fn(function()
        if vim.api.nvim_buf_is_valid(args.buf) then
          strings.convert(args.buf)
        end
      end, 1)
    end,
  })
end

---@internal
--- Register the strings domain's FileType trigger on its filetypes.
---@return nil
local function setup_strings()
  local group = lib.augroup("cascade_strings")
  local strings = require("cascade.strings")
  local fts = strings.filetypes()
  if #fts == 0 then
    return
  end
  autocmd.create("FileType", function(args)
    bind_strings_buffer(args.buf)
  end, {
    group = group,
    pattern = fts,
    desc = "cascade: bind the strings domain's triggers",
  })
  -- Cover the buffer already open at setup time.
  if ft_in(fts, vim.bo.filetype) then
    bind_strings_buffer(vim.api.nvim_get_current_buf())
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

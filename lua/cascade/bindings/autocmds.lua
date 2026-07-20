---@module 'cascade.bindings.autocmds'
---@brief Autocommands: per-filetype list keymaps and the save-time renumber.
---@description
--- Two autocmds, both idempotent (their augroups are cleared on every setup):
---   - a FileType autocmd that binds the buffer-local list keys on the
---     configured `lists.filetypes` (only when the preset is enabled);
---   - a BufWritePre autocmd that renumbers ordered lists on save (only when
---     "save" is a configured `lists.renumber.on` trigger).

local config = require("cascade.config")
local Context = require("cascade.core.context")
local renumber = require("cascade.lists.renumber")
local autocmd = require("lib.nvim.autocmd")
local lib = require("cascade.util.lib")

local M = {}

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

--- Bind the buffer-local list keys per filetype (preset only).
---@param cfg CascadeConfig
---@return nil
local function setup_list_keymaps(cfg)
  if not (cfg.lists.enable and type(cfg.lists.filetypes) == "table" and #cfg.lists.filetypes > 0) then
    return
  end
  local keymaps = require("cascade.bindings.keymaps")
  local group = lib.augroup("cascade_list_keymaps")
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

--- Register cascade's autocmds.
---@param cfg CascadeConfig
---@return nil
function M.setup(cfg)
  if cfg.keymaps and cfg.keymaps.preset then
    setup_list_keymaps(cfg)
  end
  setup_save_renumber()
end

return M

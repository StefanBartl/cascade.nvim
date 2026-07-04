---@module 'cascade.bindings'
---@brief Orchestrates cascade's bindings: keymaps, user commands, autocmds.
---@description
--- Always defines the `:Cascade*` user commands. When `keymaps.preset` is
--- enabled it also binds the global preset maps (directly onto the facade
--- actions, no `<Plug>` indirection) and the per-filetype list keys. The
--- save-time renumber autocmd is registered independently of the preset (it
--- follows `lists.renumber.on`).

local M = {}

--- Wire up every binding for the resolved config.
---@param cfg CascadeConfig
---@return nil
function M.setup(cfg)
  local keymaps = require("cascade.bindings.keymaps")
  require("cascade.bindings.usrcmds").setup()
  if cfg.keymaps and cfg.keymaps.preset then
    keymaps.bind_preset_globals(cfg)
    -- Label the <leader>c prefix in which-key (no-op if not installed).
    require("cascade.bindings.which_key").setup()
  end
  require("cascade.bindings.autocmds").setup(cfg)
end

return M

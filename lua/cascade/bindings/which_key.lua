---@module 'cascade.bindings.which_key'
---@brief Optional, guarded which-key group label for the `<leader>c` prefix.
---@description
--- which-key is a **soft** dependency: if it is not installed this is a no-op.
--- When present, we register a single group label so the preset's `<leader>c*`
--- list keys (checkbox, cycle type, renumber, rotate, sort, reverse, strip)
--- show up under a named "Cascade" group instead of a bare prefix. Individual
--- key descriptions already come from each mapping's `desc`, so nothing else
--- needs registering. Supports both the which-key v3 (`add`) and v2
--- (`register`) APIs.

local M = {}

--- Register the `<leader>c` group with which-key, if available.
---@return boolean registered
function M.setup()
  local ok, wk = pcall(require, "which-key")
  if not ok or type(wk) ~= "table" then
    return false
  end
  if type(wk.add) == "function" then
    -- which-key v3
    wk.add({ { "<leader>c", group = "Cascade", mode = { "n", "x" } } })
    return true
  elseif type(wk.register) == "function" then
    -- which-key v2
    wk.register({ ["<leader>c"] = { name = "+Cascade" } }, { mode = "n" })
    wk.register({ ["<leader>c"] = { name = "+Cascade" } }, { mode = "x" })
    return true
  end
  return false
end

--- Whether which-key is installed (for :checkhealth reporting).
---@return boolean
function M.available()
  local ok, wk = pcall(require, "which-key")
  return ok and type(wk) == "table"
end

return M

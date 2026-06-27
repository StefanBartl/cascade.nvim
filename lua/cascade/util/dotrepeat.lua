---@module 'cascade.util.dotrepeat'
---@brief Central dot-repeat (`.`) support via `operatorfunc` + `g@`.
---@description
--- Neovim records `g@<motion>` together with the active `operatorfunc` in the
--- dot register. By routing every repeatable action through a single, stable
--- `operatorfunc` entry point we get `.`-repeat for free, without each feature
--- re-implementing the trick. Actions register under a string key; the last key
--- is replayed on repeat.

local M = {}

---@type table<string, fun()>
local store = {}

---@type string|nil
M._last = nil

--- Operator-function entry point. Invoked by `g@` with the motion type, which we
--- ignore (we always operate at the cursor). Public so `v:lua` can reach it.
---@return nil
function M.run()
  local key = M._last
  if not key then
    return
  end
  local fn = store[key]
  if type(fn) == "function" then
    pcall(fn)
  end
end

--- Wrap `fn` into a dot-repeatable trigger.
---@param key string # Unique, stable identifier for this action.
---@param fn fun() # The effect to run (and to replay on `.`).
---@return fun() # Call this from a keymap.
function M.repeatable(key, fn)
  store[key] = fn
  return function()
    M._last = key
    vim.o.operatorfunc = "v:lua.require'cascade.util.dotrepeat'.run"
    vim.api.nvim_feedkeys("g@l", "n", false)
  end
end

return M

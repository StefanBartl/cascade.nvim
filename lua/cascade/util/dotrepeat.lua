---@module 'cascade.util.dotrepeat'
---@brief Central dot-repeat (`.`) support via `operatorfunc` + `g@`.
---@description
--- Neovim records `g@<motion>` together with the active `operatorfunc` in the
--- dot register. By routing every repeatable action through a single, stable
--- entry point we get `.`-repeat for free, without each feature re-implementing
--- the trick. Actions register under a string key; the last key is replayed on
--- repeat. The actual operatorfunc/g@l mechanics delegate to the soft lib.nvim
--- bridge (util/lib.lua): lib.nvim.dotrepeat when available, else an
--- equivalent standalone fallback.

local M = {}

---@type table<string, fun()>
local store = {}

---@type string|nil
M._last = nil

--- Wrap `fn` into a dot-repeatable trigger.
---@param key string # Unique, stable identifier for this action.
---@param fn fun() # The effect to run (and to replay on `.`).
---@return fun() # Call this from a keymap.
function M.repeatable(key, fn)
  store[key] = fn
  return function()
    M._last = key
    require("cascade.util.lib").dotrepeat_run(function()
      local stored = store[key]
      if type(stored) == "function" then
        pcall(stored)
      end
    end)
  end
end

return M

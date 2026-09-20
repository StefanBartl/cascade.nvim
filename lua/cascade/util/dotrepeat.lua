---@module 'cascade.util.dotrepeat'
--- Central dot-repeat (`.`) support via `operatorfunc` + `g@`.
---
--- Neovim records `g@<motion>` together with the active `operatorfunc` in the
--- dot register. By routing every repeatable action through a single, stable
--- entry point we get `.`-repeat for free, without each feature re-implementing
--- the trick. Actions register under a string key; the last key is replayed on
--- repeat. The actual operatorfunc/g@l mechanics delegate to the soft lib.nvim
--- bridge (util/lib.lua): lib.nvim.dotrepeat when available, else an
--- equivalent standalone fallback. Either way, that same bridge also calls
--- the classic vim-repeat plugin's `repeat#set`, if installed -- optional
--- interop alongside the operatorfunc trick, never a dependency on it.

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
    local lib = require("cascade.util.lib")
    lib.dotrepeat_run(function()
      local stored = store[key]
      if type(stored) == "function" then
        -- This is the actual entry point most dot-repeatable actions run
        -- through (not just `.`-repeat itself, since `dotrepeat_run` also
        -- fires synchronously on the very first press) -- collapsing a real
        -- crash here into total silence would be indistinguishable from the
        -- key legitimately doing nothing (same ERR-11 shape as
        -- dispatch.try/strings.convert/packs.resolve elsewhere in this
        -- codebase).
        local ok, err = pcall(stored)
        if not ok then
          lib.notify("action failed: " .. tostring(err), vim.log.levels.WARN)
        end
      end
    end)
  end
end

return M

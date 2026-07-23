---@module 'cascade.dispatch'
---@brief Try registered handlers in order; fall back to a native key.
---@description
--- The shared abstraction behind both domains: given an ordered list of handler
--- functions, run each with the context until one reports it handled the action
--- (returns true). If none do, feed the native key so the editor's default
--- behavior is preserved. Handlers are pure-ish predicates over a context.
--- This is cascade's detect -> advance -> fallback chain of responsibility, so
--- it's one of the two places (with `lists_active()` in init.lua) instrumented
--- for `cascade.debug` -- see `cascade.util.lib.debug_log`.

local Context = require("cascade.core.context")
local config = require("cascade.config")
local lib = require("cascade.util.lib")

local M = {}

---@alias CascadeHandler fun(ctx: CascadeContext): boolean

--- Feed a native normal-mode key without remapping.
---@param lhs string
---@return nil
local function feed_native(lhs)
  vim.api.nvim_feedkeys(vim.keycode(lhs), "n", false)
end

--- Run handlers in order against a fresh context.
---@param handlers CascadeHandler[]
---@param ctx CascadeContext|nil # Reuses this context if given, else builds one.
---@return boolean handled
function M.try(handlers, ctx)
  ctx = ctx or Context.new()
  local debug = config.get("debug") == true
  for i = 1, #handlers do
    local ok, handled = pcall(handlers[i], ctx)
    lib.debug_log(debug, "dispatch.try: handler tried", { index = i, ok = ok, handled = handled == true })
    if ok and handled then
      return true
    end
  end
  lib.debug_log(debug, "dispatch.try: no handler matched")
  return false
end

--- Run handlers; if none handled it, feed `fallback` as a native key.
---@param handlers CascadeHandler[]
---@param fallback string # e.g. "<CR>", "<C-y>".
---@param ctx CascadeContext|nil
---@return boolean handled
function M.try_or_native(handlers, fallback, ctx)
  if M.try(handlers, ctx) then
    return true
  end
  lib.debug_log(config.get("debug") == true, "dispatch.try_or_native: falling back to native key", { fallback = fallback })
  feed_native(fallback)
  return false
end

return M

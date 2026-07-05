-- docs/TESTS/harness.lua — tiny assertion helper shared by the spec files.
-- Returned to each spec by docs/TESTS/run.lua.

local H = {}

--- Assert equality; raises a descriptive error on mismatch (caught by the runner).
---@param a any # actual
---@param b any # expected
---@param msg string|nil
function H.eq(a, b, msg)
  if a ~= b then
    error(("FAIL %s: expected %q, got %q"):format(msg or "", tostring(b), tostring(a)), 2)
  end
end

--- Assert a truthy value.
---@param v any
---@param msg string|nil
function H.ok(v, msg)
  if not v then
    error(("FAIL %s: expected truthy, got %q"):format(msg or "", tostring(v)), 2)
  end
end

--- Fresh scratch buffer, made current, with an optional filetype.
--- `buftype=nofile`, so `cascade.core.context.writable()` is false — fine for
--- exercising the `lists.*`/`cycle.*` modules directly, but any test that goes
--- through the `cascade` facade (which gates on `writable()`) needs `H.editable`
--- instead.
---@param ft string|nil
---@return integer bufnr
function H.scratch(ft)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(buf)
  if ft then
    vim.bo[buf].filetype = ft
  end
  return buf
end

--- Fresh normal (non-scratch) buffer, made current, with an optional filetype.
--- `buftype=""`, so it passes `cascade.core.context.writable()` — use this for
--- facade-level tests (`cascade.indent()`, keymap-triggered actions, …).
---@param ft string|nil
---@return integer bufnr
function H.editable(ft)
  local buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_set_current_buf(buf)
  if ft then
    vim.bo[buf].filetype = ft
  end
  return buf
end

return H

---@module 'cascade.lists.format'
---@brief Buffer-local `'formatlistpat'`/`'formatoptions'` for hanging-indent wrap.
---@description
--- Native `gq`/auto-wrap already knows how to hang-indent a wrapped list item
--- once `'formatoptions'` includes `n` and `'formatlistpat'` matches the
--- marker prefix — cascade doesn't need to reimplement wrapping itself, only
--- teach Vim the currently configured marker syntax (unordered bullets,
--- ordered digit/ascii/roman, an optional checkbox) so a long item wraps with
--- its continuation aligned under the text instead of back at the margin.

local M = {}

--- Escape a literal character for a Vim (non-`\v`) regex.
---@param c string
---@return string
local function esc(c)
  return (c:gsub("([%^%$%.%*%[%]~/\\])", "\\%1"))
end

--- Vim-regex char-class matching any configured unordered bullet.
---@param markers string[]
---@return string
local function unordered_class(markers)
  local parts = {}
  for i = 1, #markers do
    parts[i] = esc(markers[i])
  end
  return "[" .. table.concat(parts) .. "]"
end

--- Build the `'formatlistpat'` value matching every configured marker kind,
--- with an optional checkbox right after — so the hanging indent lands past
--- `"1. [x] "`, not just `"1. "`.
---@param opts CascadeListOpts
---@return string # "" if no ordered/unordered kind is configured.
function M.list_pat(opts)
  local alts = {}
  local types = opts.types or {}
  for i = 1, #types do
    local t = types[i]
    if t == "unordered" then
      alts[#alts + 1] = "\\s*" .. unordered_class(opts.unordered_markers) .. "\\s\\+"
    elseif t == "digit" then
      alts[#alts + 1] = "\\s*\\d\\+[.)]\\s\\+"
    elseif t == "ascii" then
      alts[#alts + 1] = "\\s*\\a[.)]\\s\\+"
    elseif t == "roman" then
      -- Approximate: any alphabetic run + delimiter (roman validity isn't
      -- worth encoding in a Vim regex just for wrap indentation).
      alts[#alts + 1] = "\\s*\\a\\+[.)]\\s\\+"
    end
  end
  if #alts == 0 then
    return ""
  end
  local body = "\\%(" .. table.concat(alts, "\\|") .. "\\)"
  return "^" .. body .. "\\%(\\[.\\{-}\\]\\s*\\)\\?"
end

--- Apply the hanging-indent options to `bufnr`: derive `'formatlistpat'` from
--- the configured marker types and add `n` to `'formatoptions'` (additive
--- only — never strips flags the filetype/user already set). No-op when
--- `opts.continue.hanging_indent` is `false` or no marker kind is enabled.
---
--- Note: some ftplugins (markdown's bundled one, notably) already register a
--- `'comments'` leader for a plain `-`/`•` bullet, and `'comments'` wins over
--- `'formatlistpat'` for a line it matches — so a `-`/`+` item without a
--- checkbox was already hanging-indented before this ran, and one *with* a
--- checkbox still only indents to the bullet, not past `[ ]`. Ordered markers
--- (digit/ascii/roman, with or without a checkbox) have no such competing
--- `'comments'` entry, so `'formatlistpat'` fully applies to those. Widening
--- `'comments'` itself to close that unordered+checkbox gap isn't attempted
--- here: it's shared with every other filetype in `lists.filetypes`
--- (tex/org/gitcommit/...), where it also governs real comment syntax.
---@param bufnr integer
---@param opts CascadeListOpts
---@return nil
function M.apply(bufnr, opts)
  if opts.continue.hanging_indent == false then
    return
  end
  local pat = M.list_pat(opts)
  if pat == "" then
    return
  end
  vim.bo[bufnr].formatlistpat = pat
  local fo = vim.bo[bufnr].formatoptions
  if not fo:find("n", 1, true) then
    vim.bo[bufnr].formatoptions = fo .. "n"
  end
end

return M

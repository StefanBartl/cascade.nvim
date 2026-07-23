---@module 'cascade.core.treesitter'
---@brief Optional Treesitter-based precision check for the list domain.
---@description
--- cascade is a pure line-scan plugin by design (see `core/patterns.lua`) --
--- no Treesitter, no syntax awareness, just fast and predictable. That's
--- blind to one real edge case: a fenced code block inside prose can contain
--- a line that merely *looks* like a list marker (a shell `- flag`, a Python
--- `# 1. note`), which the plain scan then treats as a real list item.
---
--- `lists.precision = "treesitter"` (default `"off"`) opts into checking
--- whether the cursor sits inside a configured "skip" node before any list
--- action runs, using whatever Treesitter parser is already installed for
--- the buffer's filetype. Every call is wrapped in `pcall`: a missing or
--- broken parser must never break cascade's default line-scan behavior --
--- it just falls back to "not inside a skip node".

local M = {}

--- Node types (per filetype) that mean "don't treat this position as a list
--- line". User-extendable/overridable via `lists.precision_nodes`.
---@type table<string, string[]>
M.default_skip_nodes = {
  markdown = { "fenced_code_block", "code_fence_content" },
  ["markdown.mdx"] = { "fenced_code_block", "code_fence_content" },
  norg = { "ranged_verbatim_tag" },
}

--- Whether `(row0, col0)` in `bufnr` sits inside one of `ft`'s skip nodes.
--- Always `false` when `opts.precision ~= "treesitter"`, when no skip-node
--- types are configured for `ft`, when the buffer has no usable parser, or
--- when the position resolves to no node at all.
---@param bufnr integer
---@param row0 integer
---@param col0 integer
---@param ft string
---@param opts CascadeListOpts
---@return boolean
function M.in_skip_node(bufnr, row0, col0, ft, opts)
  if opts.precision ~= "treesitter" then
    return false
  end
  local nodes = opts.precision_nodes
  local types = (type(nodes) == "table" and nodes[ft]) or M.default_skip_nodes[ft]
  if not types or #types == 0 then
    return false
  end

  local ok, hit = pcall(function()
    local parser = vim.treesitter.get_parser(bufnr, ft)
    local root = parser:parse()[1]:root()
    local node = root:named_descendant_for_range(row0, col0, row0, col0)
    while node do
      local t = node:type()
      for i = 1, #types do
        if types[i] == t then
          return true
        end
      end
      node = node:parent()
    end
    return false
  end)
  return ok and hit or false
end

return M

---@module 'cascade.bindings.usrcmds'
---@brief The `:Cascade <subcommand>` verb (range-aware; normal + visual),
---@brief built via lib.nvim's composer (:Verb sub … + <Tab> completion +
---@brief Markdown docgen).
---@description
--- Thin command wrappers over the facade actions. Every transform command is
--- range-aware: without a range it acts on the list block at the cursor, with a
--- range on the selected lines. `run_command`/`run_indent_command` only read
--- `.range`/`.line1`/`.line2` off their `cmd` argument, so `ctx.raw` (the
--- untouched nvim callback args) is passed through unchanged — direction is
--- computed from the composer-typed `ctx.bang`/`ctx.args` instead of raw
--- string comparison.

local composer = require("lib.nvim.usercmd.composer")

local M = {}

--- Create the :Cascade verb (range-aware; works in normal and visual mode).
---@return nil
function M.setup()
  local api = require("cascade")

  composer.verb("Cascade", {
    desc = "Cascade: list transforms (range-aware; normal + visual)",
    routes = {
      { path = { "rotate" }, bang = true, range = true,
        args = { { name = "dir", type = "STRING", enum = { "next", "prev" }, optional = true } },
        desc = "Rotate list form (range-aware; ! or 'prev' = backward)",
        run = function(ctx)
          local dir = (ctx.args.dir == "prev" or ctx.bang) and -1 or 1
          api.run_command(api._transform.rotate, ctx.raw, dir)
        end },

      { path = { "sort" }, bang = true, range = true,
        desc = "Sort list A-Z (range-aware; ! = Z-A)",
        run = function(ctx)
          local dir = ctx.bang and -1 or 1 -- ! = descending (Z-A)
          api.run_command(api._transform.sort, ctx.raw, dir)
        end },

      { path = { "reverse" }, range = true,
        desc = "Reverse list order (range-aware)",
        run = function(ctx) api.run_command(api._transform.reverse, ctx.raw, 1) end },

      { path = { "strip" }, range = true,
        desc = "Strip checkboxes (range-aware)",
        run = function(ctx) api.run_command(api._transform.strip, ctx.raw, 1) end },

      { path = { "indent" }, range = true,
        args = { { name = "levels", type = "INT", optional = true } },
        desc = "Indent line/range (+renumber; arg = levels)",
        run = function(ctx) api.run_indent_command(ctx.raw, 1) end },

      { path = { "dedent" }, range = true,
        args = { { name = "levels", type = "INT", optional = true } },
        desc = "Dedent line/range (+renumber; arg = levels)",
        run = function(ctx) api.run_indent_command(ctx.raw, -1) end },

      { path = { "renumber" }, range = true,
        args = { { name = "scope", type = "STRING", enum = { "all" }, optional = true } },
        desc = "Renumber list block (range-aware; 'all' = every list in the buffer)",
        run = function(ctx) api.run_renumber_command(ctx.raw, ctx.args.scope) end },
    },
  })
end

return M

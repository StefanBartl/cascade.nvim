---@module 'cascade.bindings.usrcmds'
---@brief The `:Cascade*` user commands (range-aware; normal + visual).
---@description
--- Thin command wrappers over the facade actions. Every transform command is
--- range-aware: without a range it acts on the list block at the cursor, with a
--- range on the selected lines.

local M = {}

--- Create the user commands (range-aware; work in normal and visual mode).
---@return nil
function M.setup()
  local api = require("cascade")

  vim.api.nvim_create_user_command("CascadeRotate", function(cmd)
    local dir = (cmd.args == "prev" or cmd.bang) and -1 or 1
    api.run_command(api._transform.rotate, cmd, dir)
  end, {
    range = true,
    bang = true,
    nargs = "?",
    complete = function()
      return { "next", "prev" }
    end,
    desc = "cascade: rotate list form (range-aware; ! = backward)",
  })

  vim.api.nvim_create_user_command("CascadeSort", function(cmd)
    local dir = cmd.bang and -1 or 1 -- ! = descending (Z-A)
    api.run_command(api._transform.sort, cmd, dir)
  end, {
    range = true,
    bang = true,
    desc = "cascade: sort list A-Z (range-aware; ! = Z-A)",
  })

  vim.api.nvim_create_user_command("CascadeReverse", function(cmd)
    api.run_command(api._transform.reverse, cmd, 1)
  end, {
    range = true,
    desc = "cascade: reverse list order (range-aware)",
  })

  vim.api.nvim_create_user_command("CascadeStrip", function(cmd)
    api.run_command(api._transform.strip, cmd, 1)
  end, {
    range = true,
    desc = "cascade: strip checkboxes (range-aware)",
  })

  vim.api.nvim_create_user_command("CascadeIndent", function(cmd)
    api.run_indent_command(cmd, 1)
  end, {
    range = true,
    nargs = "?",
    desc = "cascade: indent line/range (+renumber; arg = levels)",
  })

  vim.api.nvim_create_user_command("CascadeDedent", function(cmd)
    api.run_indent_command(cmd, -1)
  end, {
    range = true,
    nargs = "?",
    desc = "cascade: dedent line/range (+renumber; arg = levels)",
  })
end

return M

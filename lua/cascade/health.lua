---@module 'cascade.health'
---@brief `:checkhealth cascade` diagnostics.
---@description
--- Reports Neovim version, whether each domain is enabled, `lib.nvim`
--- availability (required — the :Cascade command layer is built on
--- lib.nvim.usercmd.composer), and basic config sanity (non-empty cycle
--- groups / checkbox states). Read-only: never mutates state.

local M = {}

--- Run the health check.
---@return nil
function M.check()
  local health = vim.health or require("health")
  local start = health.start or health.report_start
  local ok = health.ok or health.report_ok
  local warn = health.warn or health.report_warn
  local info = health.info or health.report_info

  start("cascade.nvim")

  if vim.fn.has("nvim-0.9") == 1 then
    ok("Neovim " .. tostring(vim.version()))
  else
    warn("cascade.nvim targets Neovim 0.9+")
  end

  local cfg_ok, config = pcall(require, "cascade.config")
  if not cfg_ok then
    warn("config module failed to load: " .. tostring(config))
    return
  end

  -- lib.nvim: required for the :Cascade command layer (lib.nvim.usercmd.composer);
  -- lib.map/lib.notify remain soft (util/lib.lua falls back to native APIs).
  if pcall(require, "lib.nvim.usercmd.composer") then
    ok("lib.nvim detected (:Cascade command layer + lib.map/lib.notify available)")
  else
    warn("lib.nvim not found — :Cascade will fail to load; install \"StefanBartl/lib.nvim\"")
  end

  -- Optional which-key integration.
  if require("cascade.bindings.which_key").available() then
    ok('which-key detected (<leader>c grouped as "Cascade" when preset is on)')
  else
    info("which-key not found — mappings still carry their own descriptions")
  end

  -- List domain.
  local lists = config.get("lists")
  if lists.enable then
    ok(("lists: enabled for { %s }"):format(table.concat(lists.filetypes, ", ")))
    if type(lists.checkbox.states) ~= "table" or #lists.checkbox.states == 0 then
      warn("lists.checkbox.states is empty — checkbox toggling disabled")
    else
      info("checkbox states: " .. table.concat(lists.checkbox.states, " -> "))
    end
    if type(lists.cycle) ~= "table" or #lists.cycle == 0 then
      warn("lists.cycle is empty — marker-type cycling disabled")
    end
    if type(lists.forms) ~= "table" or #lists.forms == 0 then
      warn("lists.forms is empty — form rotation disabled")
    end
    local r = lists.renumber
    if type(r) == "table" and r.enable and type(r.on) == "table" and #r.on > 0 then
      info(("renumber: on (%s); indent/outdent is indent-level aware"):format(table.concat(r.on, ", ")))
    else
      info("renumber: off — only manual :Cascade renumber re-sequences lists")
    end
  else
    info("lists: disabled")
  end

  -- Cycle domain.
  local cyc = config.get("cycle")
  if cyc.enable then
    local scope = cyc.filetypes and table.concat(cyc.filetypes, ", ") or "all filetypes"
    ok(("cycle: enabled (%s), %d groups"):format(scope, #cyc.groups))
    if cyc.number_fallback then
      info("number fallback: native <C-y>/<C-x> on numeric tokens")
    end
  else
    info("cycle: disabled")
  end

  -- Transpose domain.
  local trans = config.get("transpose")
  if trans.enable then
    ok("transpose: enabled (all filetypes)")
  else
    info("transpose: disabled")
  end
end

return M

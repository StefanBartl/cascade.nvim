---@module 'cascade.health'
--- `:checkhealth cascade` diagnostics.
---
--- Reports Neovim version, whether each domain is enabled, `lib.nvim`
--- availability (required — the :Cascade command layer is built on
--- lib.nvim.bindings.usercmd.composer), and basic config sanity (non-empty cycle
--- groups / checkbox states). Read-only: never mutates state.

local M = {}

--- Run the health check.
---@return nil
function M.check()
  local health = vim.health or require("health")
  local start = health.start or health.report_start
  local ok = health.ok or health.report_ok
  local warn = health.warn or health.report_warn
  local err = health.error or health.report_error
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

  -- lib.nvim: required for the :Cascade command layer (lib.nvim.bindings.usercmd.composer);
  -- lib.map/lib.notify remain soft (util/lib.lua falls back to native APIs).
  if pcall(require, "lib.nvim.bindings.usercmd.composer") then
    ok("lib.nvim detected (:Cascade command layer + lib.map/lib.notify available)")
  else
    err('lib.nvim not found — :Cascade will fail to load; install "StefanBartl/lib.nvim"')
  end

  -- Optional which-key integration.
  if pcall(require, "which-key") then
    ok('which-key detected (<leader>c grouped as "Cascade" when preset is on)')
  else
    info("which-key not found — mappings still carry their own descriptions")
  end

  -- Debug logging (detect/advance/fallback at dispatch.try + lists_active()).
  if config.get("debug") == true then
    if pcall(require, "lib.nvim.logger") then
      ok("debug: enabled, lib.nvim.logger available (structured logs + :LibLogger)")
    else
      info("debug: enabled, lib.nvim.logger not found — falling back to vim.notify at DEBUG level")
    end
  else
    info("debug: disabled (cascade.debug = true to enable)")
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
    local packs_mod = require("cascade.cycle.packs")
    local pack_names = type(cyc.packs) == "table" and cyc.packs or {}
    local pack_groups = packs_mod.resolve(pack_names)
    local scope = cyc.filetypes and table.concat(cyc.filetypes, ", ") or "all filetypes"
    ok(("cycle: enabled (%s), %d own groups + %d from packs"):format(scope, #cyc.groups, #pack_groups))
    info(
      #pack_names > 0 and ("packs: %s (order = precedence)"):format(table.concat(pack_names, ", "))
        or "packs: none — only cycle.groups is active"
    )
    if cyc.number_fallback then
      info("number fallback: native <C-y>/<C-x> on numeric tokens")
    end

    -- A word may only live in one group of the effective set: `find_group`
    -- takes the first, so any later group holding it is unreachable. Easy to
    -- hit once several language packs are on ("no" is English and Spanish).
    local effective = {}
    for i = 1, #cyc.groups do
      effective[#effective + 1] = cyc.groups[i]
    end
    for i = 1, #pack_groups do
      effective[#effective + 1] = pack_groups[i]
    end
    local clashes = packs_mod.conflicts(effective)
    if #clashes > 0 then
      local lines = {}
      for i = 1, math.min(#clashes, 8) do
        local c = clashes[i]
        lines[#lines + 1] = ("  %q → { %s } wins, { %s } unreachable"):format(
          c.word,
          table.concat(c.winner, ", "),
          table.concat(c.shadowed, ", ")
        )
      end
      if #clashes > 8 then
        lines[#lines + 1] = ("  … and %d more"):format(#clashes - 8)
      end
      warn(("%d word(s) appear in more than one cycle group:\n%s"):format(#clashes, table.concat(lines, "\n")))
    end
  else
    info("cycle: disabled")
  end

  -- Sequence domain (renumber inside a selection).
  local seq = config.get("sequence")
  if type(seq) == "table" and seq.enable then
    ok(("sequence: enabled (all filetypes), types { %s }"):format(table.concat(seq.types, ", ")))
    info(
      seq.start == "one" and "sequence start: one — every run restarts at 1/a/i"
        or "sequence start: keep — the first hit sets the start value"
    )
  else
    info("sequence: disabled")
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

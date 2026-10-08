-- TESTS/usrcmds_help_spec.lua -- every positional argument of `:Cascade` has a line in lib.nvim's
-- option float.
--
-- The text comes from the `desc` / `enum_desc` of each ArgSpec in cascade.bindings.usrcmds (`cycle
-- add`, `cycle remove`, `strings`, `rotate`, `renumber`); `indent` / `dedent` take a built-in INT,
-- which explains itself. `:Cascade` has no flags or key=value pairs. An argument without a text
-- shows up as a bare row in the cheatsheet, so this fails until it is described.

return function(H)
  local ok, composer = pcall(require, "lib.nvim.bindings.usercmd.composer")
  H.ok(ok, "the composer loads")

  -- A lib.nvim older than `help.undocumented` cannot answer the question; that is a missing
  -- feature of the dependency, not a defect of this plugin.
  if type(composer.help.undocumented) ~= "function" then
    return
  end

  require("cascade").setup({})
  H.ok(composer.registry().Cascade ~= nil, ":Cascade is registered through the composer")

  local missing = {}
  for _, m in ipairs(composer.help.undocumented("Cascade", { args = true })) do
    missing[#missing + 1] = ("%s %s %s"):format(m.kind, m.route, m.name)
  end
  H.eq(#missing, 0, ":Cascade entries without a help text: " .. table.concat(missing, ", "))

  -- The texts follow the house style: one line, no trailing period, at most 80 characters; an
  -- `enum_desc` key is a value the argument really offers.
  local texts, stray, malformed = 0, {}, {}
  for _, route in ipairs(composer.registry().Cascade:spec().routes) do
    for _, arg in ipairs(route.args or {}) do
      local offered = {}
      for _, value in ipairs(arg.enum or arg.values or {}) do
        offered[value] = true
      end
      local all = { arg.desc }
      for value, text in pairs(arg.enum_desc or {}) do
        all[#all + 1] = text
        if not offered[value] then
          stray[#stray + 1] = arg.name .. "=" .. value
        end
      end
      for _, text in ipairs(all) do
        texts = texts + 1
        if text:find("\n", 1, true) or text:sub(-1) == "." or #text > 80 then
          malformed[#malformed + 1] = text
        end
      end
    end
  end
  H.ok(texts >= 8, "the argument texts were found")
  H.eq(#malformed, 0, "texts must be one line, no trailing period, <= 80 chars: " .. table.concat(malformed, " | "))
  H.eq(#stray, 0, "enum_desc keys that are no value: " .. table.concat(stray, ", "))
end

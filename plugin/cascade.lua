-- plugin/cascade.lua
-- Load guard. Keeps the plugin from initializing twice and lets users disable
-- it entirely via `vim.g.loaded_cascade = 1` before it is sourced.

if vim.g.loaded_cascade then
  return
end
vim.g.loaded_cascade = 1

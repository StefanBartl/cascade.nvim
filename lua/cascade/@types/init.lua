---@module 'cascade.types'
---@brief Central type declarations for cascade.nvim.
---@description
--- Keeps the source files free of large annotation blocks. Every type that is
--- shared across more than one module lives here. This file intentionally
--- returns an empty table; it exists purely for the Lua language server.

-- #####################################################################
-- config/DEFAULTS.lua

---@class CascadeCheckboxOpts
---@field states string[] # Ordered single-char states cycled inside `[ ]` (e.g. { " ", "x" }).

---@class CascadeContinueOpts
---@field delete_empty boolean # `<CR>` on an empty bullet removes the bullet instead of continuing.

---@class CascadeListOpts
---@field enable boolean # Master switch for the list domain.
---@field filetypes string[] # Filetypes the list features attach to.
---@field types CascadeMarkerKind[] # Enabled ordered/unordered marker kinds, in detection order.
---@field unordered_markers string[] # Accepted unordered bullet characters.
---@field cycle string[] # Marker shapes cycled by `cycle_type` (e.g. { "-", "*", "1.", "a)" }).
---@field forms string[] # Block/visual form rotation: shape + optional checkbox (e.g. { "1.", "1. [ ]", "- [ ]", "-" }).
---@field checkbox CascadeCheckboxOpts
---@field continue CascadeContinueOpts
---@field renumber boolean # Auto-renumber ordered lists after structural edits.

---@class CascadeCycleOpts
---@field enable boolean # Master switch for the word/number cycle domain.
---@field filetypes string[]|nil # Restrict to these filetypes; nil = every filetype (global).
---@field number_fallback boolean # Fall back to native <C-a>/<C-x> on numeric tokens.
---@field groups string[][] # Cycle groups; first match under the cursor wins.
---@field per_filetype table<string, string[][]> # Extra groups merged in per filetype.

---@class CascadeKeymapOpts
---@field preset boolean # Bind the opinionated default keymaps on setup.

---@class CascadeConfig
---@field lists CascadeListOpts
---@field cycle CascadeCycleOpts
---@field keymaps CascadeKeymapOpts

-- #####################################################################
-- core/context.lua

---@class CascadeContext
---@field bufnr integer # Resolved buffer handle.
---@field row0 integer # Cursor row, 0-based.
---@field col0 integer # Cursor column, 0-based byte index.
---@field line string # Full text of the cursor line.
---@field ft string # Filetype of the buffer.

-- #####################################################################
-- lists/marker.lua

---@alias CascadeMarkerKind "unordered"|"digit"|"ascii"|"roman"

---@class CascadeMarker
---@field indent string # Leading whitespace of the line.
---@field kind CascadeMarkerKind # Detected marker family.
---@field marker string # Raw marker token ("-", "1", "a", "iv", ...).
---@field delim string # Delimiter after ordered markers ("." or ")"); "" for unordered.
---@field checkbox string|nil # Inner checkbox char if the item has one, else nil.
---@field text string # Item content after the marker (and checkbox).

return {}

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

---@alias CascadeRenumberTrigger "edit"|"save"

---@class CascadeRenumberOpts
---@field enable boolean # Master switch for automatic renumbering.
---@field on CascadeRenumberTrigger[] # When it runs: "edit" and/or "save".

---@class CascadeListFeatures
---@field continue boolean # `<CR>`/`o`/`O` continuation and empty-bullet deletion.
---@field checkbox boolean # Toggle/cycle checkbox action.
---@field cycle_type boolean # Cycle a single item's marker shape.
---@field rotate boolean # Block/visual form rotation.
---@field sort boolean # Block/visual A-Z sort.
---@field reverse boolean # Block/visual reverse order.
---@field strip boolean # Block/visual remove checkboxes.
---@field indent boolean # Indent/outdent with level-aware renumber.
---@field move boolean # Move line/selection up/down with renumber.

---@class CascadeCycleFeatures
---@field word boolean # Cycle the word/boolean under the cursor.

---@class CascadeListOpts
---@field enable boolean # Master switch for the list domain.
---@field features CascadeListFeatures # Per-feature on/off switches.
---@field filetypes string[] # Filetypes the list features attach to.
---@field types CascadeMarkerKind[] # Enabled ordered/unordered marker kinds, in detection order.
---@field unordered_markers string[] # Accepted unordered bullet characters.
---@field cycle string[] # Marker shapes cycled by `cycle_type` (e.g. { "-", "*", "1.", "a)" }).
---@field forms string[] # Block/visual form rotation: shape + optional checkbox (e.g. { "1.", "1. [ ]", "- [ ]", "-" }).
---@field checkbox CascadeCheckboxOpts
---@field continue CascadeContinueOpts
---@field renumber CascadeRenumberOpts # When ordered lists are auto-renumbered.

---@class CascadeCycleOpts
---@field enable boolean # Master switch for the word/number cycle domain.
---@field features CascadeCycleFeatures # Per-feature on/off switches.
---@field filetypes string[]|nil # Restrict to these filetypes; nil = every filetype (global).
---@field number_fallback boolean # Fall back to native <C-y>/<C-x> on numeric tokens.
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

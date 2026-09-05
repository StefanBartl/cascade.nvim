---@meta
---@module 'cascade.@types'
--- Central type declarations for cascade.nvim.
---
--- Keeps the source files free of large annotation blocks. Every type that is
--- shared across more than one module lives here. This file intentionally
--- returns an empty table; it exists purely for the Lua language server.

-- #####################################################################
-- config/DEFAULTS.lua

---@class CascadeCheckboxOpts
--- A state is normally one character; longer states (e.g. the emoji `"✅"`) are
--- supported but must be listed in `states` to be recognized on parse.
---@field states string[] # Ordered states cycled inside `[ ]` (e.g. { " ", "x" }).

---@class CascadeContinueOpts
---@field delete_empty boolean # `<CR>` on an empty bullet removes the bullet instead of continuing.
---@field hanging_indent boolean # Set buffer-local 'formatlistpat'/'formatoptions' so `gq`/auto-wrap hang-indents a wrapped item.

---@alias CascadeRenumberTrigger "edit"|"save"

---@class CascadeRenumberOpts
---@field enable boolean # Master switch for automatic renumbering.
---@field on CascadeRenumberTrigger[] # When it runs: "edit" and/or "save".
---@field blank_break integer # Consecutive blank lines that end a block (0 = any blank line breaks it).

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
---@field bullet_toggle boolean # Quick "-" bullet on/off; works without an existing marker.
---@field number_toggle boolean # Quick "1." marker on/off; works without an existing marker.
---@field checkbox_toggle boolean # Quick "- [ ]" insert/cycle/remove; works without an existing marker.

---@class CascadeCycleFeatures
---@field word boolean # Cycle the word/boolean under the cursor.
---@field date boolean # Step the year/month/day segment of an ISO date (YYYY-MM-DD) under the cursor.
---@field letter boolean # Cycle a single a-z/A-Z letter under the cursor through the alphabet (case preserved).
---@field char boolean # Step the char under the cursor through the alphabet, inside a word too (`<C-M-y>`/`<C-M-x>`).

---@class CascadeListOpts
---@field enable boolean # Master switch for the list domain.
---@field features CascadeListFeatures # Per-feature on/off switches.
---@field filetypes string[] # Filetypes the list features attach to.
---@field types CascadeMarkerKind[] # Enabled ordered/unordered marker kinds, in detection order.
---@field unordered_markers string[] # Accepted unordered bullet characters.
---@field per_filetype_patterns table<string, string[]> # Custom marker patterns per filetype, tried before `types` (see DEFAULTS)
---@field cycle string[] # Marker shapes cycled by `cycle_type` (e.g. { "-", "*", "1.", "a)" }).
---@field forms string[] # Block/visual form rotation: shape + optional checkbox (e.g. { "1.", "1. [ ]", "- [ ]", "-" }).
---@field checkbox CascadeCheckboxOpts
---@field continue CascadeContinueOpts
---@field renumber CascadeRenumberOpts # When ordered lists are auto-renumbered.
---@field precision "off"|"treesitter" # "treesitter" skips list actions inside a configured skip node (see core.treesitter).
---@field precision_nodes table<string, string[]> # Per-filetype skip-node overrides (precision "treesitter"; see core.treesitter)

---@class CascadeCycleOpts
---@field enable boolean # Master switch for the word/number cycle domain.
---@field features CascadeCycleFeatures # Per-feature on/off switches.
---@field filetypes string[]|nil # Restrict to these filetypes; nil = every filetype (global).
---@field number_fallback boolean # Fall back to native <C-y>/<C-x> on numeric tokens.
---@field packs CascadeCyclePack[] # Built-in group bundles to enable; order = precedence.
---@field groups string[][] # Cycle groups; first match under the cursor wins. Checked before `packs`.
---@field per_filetype table<string, string[][]> # Extra groups merged in per filetype.

--- A bundle shipped in `cascade/cycle/packs/`: a language's boolean/state
--- vocabulary, or the language-neutral developer cycles ("dev").
---@alias CascadeCyclePack "en"|"de"|"es"|"fr"|"it"|"pt"|"nl"|"ru"|"dev"

---@alias CascadeSequenceKind "digit"|"ascii"|"roman"

---@class CascadeSequenceOpts
---@field enable boolean # Master switch for the selection-renumber domain.
---@field start "keep"|"one" # "keep" = start from the first hit's value; "one" = always restart at 1/a/i.
---@field types CascadeSequenceKind[] # Kinds tried, in order, to classify the first hit (which locks the kind).

---@class CascadeSequenceState
--- Carry-over state for `cascade.sequence.renumber.rewrite`, so one sequence
--- can span several lines. Start a run with a fresh `{}`.
---@field kind CascadeSequenceKind|nil # Kind the first hit committed the run to.
---@field next integer|nil # Value the next hit receives.

---@class CascadeTransposeFeatures
---@field char boolean # Swap the char (or same-line selection) with its left/right neighbor.
---@field word boolean # Swap the word (or same-line selection) with its left/right neighbor word.

---@class CascadeTransposeOpts
---@field enable boolean # Master switch for the transpose domain.
---@field features CascadeTransposeFeatures # Per-feature on/off switches.

---@class CascadeKeymapOpts
---@field preset boolean # Bind the opinionated default keymaps on setup.
---@field globals? table<string, string|string[]|false> # Per-action overrides for the keys that work everywhere; `false` drops one. Names: bindings/keymaps.lua.
---@field list? table<string, string|string[]|false> # The same, for the keys bound inside a matched buffer.

---@class CascadeConfig
---@field lists? CascadeListOpts
---@field cycle? CascadeCycleOpts
---@field sequence? CascadeSequenceOpts
---@field transpose? CascadeTransposeOpts
---@field keymaps? CascadeKeymapOpts
---@field debug? boolean # Debug logging at cascade's central decision points (see util/lib.lua's debug_log).

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

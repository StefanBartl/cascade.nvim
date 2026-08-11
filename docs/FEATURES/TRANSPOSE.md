# Transpose

Swaps a character or a word — or a same-line Visual selection — with its
left/right neighbor. UTF-8 safe, global (no filetype option at all:
swapping characters/words is filetype-agnostic by nature). Each feature
can be switched off individually via `transpose.features.*`.

## Char swap

Swaps the character under the cursor with its left or right neighbor
character. UTF-8 safe, dot-repeatable; a numeric count swaps N times in a
row, stopping early (not erroring) at the line boundary.

- **Module:** `transpose/char.lua` (`M.char`)
- **Config:** `transpose.features.char`
- **Keymaps:** `<leader><Right>` / `<leader><Left>` (global, normal, preset)

## Word swap

Swaps the word under the cursor with its left or right neighbor word.
Dot-repeatable; a numeric count swaps N times, stopping early if no
neighbor word remains.

- **Module:** `transpose/word.lua` (`M.word`)
- **Config:** `transpose.features.word`
- **Keymaps:** `<leader><C-Right>` / `<leader><C-Left>` (global, normal, preset)

## Selection swap

Swaps a same-line Visual selection with its left/right neighbor character
or word. The neighbor moves into the selection's old slot and the
selection is re-drawn around the swapped text, not the original span; a
count swaps N times. No-op across multiple lines or at a line boundary —
falls back to reselecting (`gv`) instead of erroring.

- **Module:** `transpose/char.lua` (`M.selection`), `transpose/word.lua` (`M.word_selection`)
- **Config:** `transpose.features.char` / `transpose.features.word` (shares the gate with the single-unit swap)
- **Keymaps:** `<leader><Right>`/`<leader><Left>` (char), `<leader><C-Right>`/`<leader><C-Left>` (word) — Visual mode, global, preset

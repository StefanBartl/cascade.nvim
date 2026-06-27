```
                                       __
   _________ _______________ _____/ /__
  / ___/ __ `/ ___/ ___/ __ `/ __  / _ \
 / /__/ /_/ (__  ) /__/ /_/ / /_/ /  __/
 \___/\__,_/____/\___/\__,_/\__,_/\___/
        context-aware lists & cycling
```

![Neovim](https://img.shields.io/badge/Neovim-0.9+-57A143?logo=neovim&logoColor=white)
![Lua](https://img.shields.io/badge/Made%20with-Lua-2C2D72?logo=lua&logoColor=white)
![License](https://img.shields.io/badge/license-MIT-blue)

> Ein Plugin, ein Muster: **Kontext unter dem Cursor erkennen → einen Schritt
> weiterführen → sonst auf natives Verhalten zurückfallen.** Das gilt für
> Markdown-Listen genauso wie für `true`/`false`-Toggles im Code.

`cascade.nvim` vereint zwei Feature-Welten unter einem Dach:

- **lists** — Listen fortführen, neu nummerieren, Checkboxen ticken,
  Marker-Typen cyclen, ein-/ausrücken (ft-scoped).
- **cycle** — das Wort unter dem Cursor weiterdrehen (`true`→`false`, `on`→`off`,
  …), mit nativem `<C-a>`/`<C-x>`-Fallback für Zahlen (global).

---

## Table of contents

- [Features](#features)
- [Installation](#installation)
- [Quickstart](#quickstart)
- [Keymaps](#keymaps)
- [Configuration](#configuration)
- [Health](#health)
- [Architektur](#architektur)
- [Roadmap](#roadmap)

---

## Features

| Domäne     | Feature                | Beschreibung                                                        |
| ---------- | ---------------------- | ------------------------------------------------------------------- |
| **lists**  | Continuation           | `<CR>`, `o`, `O` setzen den nächsten Bullet (inkl. Increment).      |
| **lists**  | Empty-bullet deletion  | `<CR>` auf leerem Bullet beendet die Liste.                         |
| **lists**  | Renumber               | Kontextbewusst, respektiert Start-Offset ≠ 1.                      |
| **lists**  | Checkbox-Cycle         | Konfigurierbarer N-Zustands-Cycle (`[ ]`→`[x]`→…), dot-repeatable.  |
| **lists**  | Cycle list type        | `-`→`*`→`+`→`1.`→`a)`→`I.`, dot-repeatable.                         |
| **lists**  | Indent / Dedent        | Ein-/Ausrücken mit automatischem Renumber.                          |
| **lists**  | Roman & Alpha          | `I.II.III.` und `a)b)c)` ↔ Integer, sauber gekapselt.              |
| **cycle**  | Word / boolean cycle   | Case-erhaltend, per-Filetype erweiterbar, dot-repeatable.          |
| **cycle**  | Number fallback        | Native `<C-a>`/`<C-x>` für int/float/hex.                          |

Sicherheits- & Performance-Designentscheidungen: kein Treesitter (reiner
Zeilen-Scan), keine `CursorMoved`/`TextChanged`-Autocmds (nur explizite Tasten),
`pcall` um alle Buffer-Mutationen, ein einziges Context-Objekt pro Aktion,
memoisierte Patterns, `:checkhealth cascade`.

---

## Installation

**lazy.nvim**

```lua
{
  "StefanBartl/cascade.nvim",
  ft = { "markdown", "markdown.mdx", "text", "tex", "norg" },
  event = "VeryLazy", -- damit der globale cycle auch in Code greift
  opts = {
    keymaps = { preset = true },
  },
}
```

**packer.nvim**

```lua
use({ "StefanBartl/cascade.nvim", config = function()
  require("cascade").setup({ keymaps = { preset = true } })
end })
```

---

## Quickstart

### Variante A — Preset (null Handarbeit)

```lua
require("cascade").setup({ keymaps = { preset = true } })
```

Bindet global `<C-a>`/`<C-x>` (Word-Cycle + Zahlen-Fallback) und in den
Listen-Filetypes buffer-lokal `<CR>`/`o`/`O` sowie `<leader>tc` (Checkbox),
`<leader>tt`/`<leader>tT` (Listentyp), `<leader>tr` (Renumber).

### Variante B — `<Plug>` (volle Kontrolle)

```lua
require("cascade").setup({}) -- definiert nur die <Plug>-Maps

vim.keymap.set("i", "<CR>",        "<Plug>(cascade-cr)")
vim.keymap.set("n", "o",           "<Plug>(cascade-o)")
vim.keymap.set("n", "O",           "<Plug>(cascade-O)")
vim.keymap.set("n", "<C-a>",       "<Plug>(cascade-cycle-word-next)")
vim.keymap.set("n", "<C-x>",       "<Plug>(cascade-cycle-word-prev)")
vim.keymap.set("n", "<Tab>",       "<Plug>(cascade-indent)")
vim.keymap.set("n", "<S-Tab>",     "<Plug>(cascade-dedent)")
```

---

## Keymaps

Alle Aktionen sind als `<Plug>`-Mappings verfügbar:

| `<Plug>`                            | Modus | Aktion                                   |
| ----------------------------------- | ----- | ---------------------------------------- |
| `<Plug>(cascade-cr)`                | i     | Liste fortführen / leeren Bullet löschen |
| `<Plug>(cascade-o)`                 | n     | Item darunter öffnen                     |
| `<Plug>(cascade-O)`                 | n     | Item darüber öffnen                      |
| `<Plug>(cascade-checkbox)`          | n     | Checkbox togglen/cyclen                  |
| `<Plug>(cascade-cycle-type-next)`   | n     | Listentyp vor                            |
| `<Plug>(cascade-cycle-type-prev)`   | n     | Listentyp zurück                         |
| `<Plug>(cascade-cycle-word-next)`   | n     | Wort/Zahl vor                            |
| `<Plug>(cascade-cycle-word-prev)`   | n     | Wort/Zahl zurück                         |
| `<Plug>(cascade-indent)`            | n     | Einrücken + Renumber                     |
| `<Plug>(cascade-dedent)`            | n     | Ausrücken + Renumber                     |
| `<Plug>(cascade-renumber)`          | n     | Block neu nummerieren                    |

> `<Tab>`/`<S-Tab>` sind bewusst **nicht** im Preset (Konflikt mit Completion).
> Bei Bedarf via `<Plug>(cascade-indent/dedent)` selbst binden.

---

## Configuration

Defaults (Auszug — vollständige Referenz in `:h cascade-config`):

```lua
require("cascade").setup({
  lists = {
    enable = true,
    filetypes = { "markdown", "markdown.mdx", "text", "tex", "norg" },
    types = { "unordered", "digit" },        -- Erkennungs-Reihenfolge
    unordered_markers = { "-", "*", "+" },
    cycle = { "-", "*", "+", "1.", "a)", "I." },
    checkbox = { states = { " ", "x" } },    -- N-Zustands-Cycle möglich
    continue = { delete_empty = true },
    renumber = true,
  },
  cycle = {
    enable = true,
    filetypes = nil,                         -- nil = alle Filetypes
    number_fallback = true,
    groups = { { "true", "false" }, { "on", "off" } },
    per_filetype = {                         -- z. B. nur in Lua:
      -- lua = { { "pairs", "ipairs" } },
    },
  },
  keymaps = { preset = false },
})
```

**Hinweis zu `types`:** `ascii` (`a)`) und `roman` (`i.`) sind opt-in, weil
Buchstaben mehrdeutig sind. Bei aktiviertem Mix entscheidet die Reihenfolge in
`types`. Templates in `lists.cycle`: `a/A` = alpha, `i/I` = roman.

---

## Health

```vim
:checkhealth cascade
```

Zeigt Neovim-Version, Domänen-Status, `lib.nvim`-Integration (optional) und
Config-Sanity.

---

## Architektur

```
cascade.nvim/
  plugin/cascade.lua          -- load guard
  lua/cascade/
    init.lua                  -- setup() + Action-Fassade
    config/{init,DEFAULTS}    -- merge + get(path)
    core/{context,patterns}   -- 1 Context/Aktion, memoisierte Patterns
    dispatch/init.lua         -- try-handlers → native fallback
    lists/                    -- marker, continue, renumber, checkbox,
                                 cycle_type, indent, roman, alpha
    cycle/                    -- token, word_cycle
    keymaps/init.lua          -- <Plug> + Preset
    util/{lib,dotrepeat}      -- guarded lib-Bridge, operatorfunc-Repeat
    health.lua
    @types/init.lua
  doc/cascade.txt             -- :h cascade
```

`lib.nvim` ist eine **weiche, geguardete** Dependency: ist sie vorhanden, werden
`lib.map`/`lib.notify`/… genutzt, andernfalls native Fallbacks — das Plugin läuft
voll standalone.

---

## Roadmap

Siehe [docs/ROADMAP.md](docs/ROADMAP.md): Subtree-aware Indent, Visual-Mode
(sort/reverse/retype), Datums-Cycle, Operator-Flips, Treesitter-Präzisionsmodus.

---

## License

MIT

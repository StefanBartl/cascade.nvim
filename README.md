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
| **lists**  | Form-Rotation          | Block/Visual durch Formen rotieren: `1.`→`1. [ ]`→`- [ ]`→`-`.      |
| **lists**  | Sort A–Z               | Block/Visual alphabetisch sortieren + Renumber.                     |
| **lists**  | Reihenfolge umkehren   | Block/Visual umdrehen + Renumber.                                   |
| **lists**  | Checkbox entfernen     | Block/Visual: `[ ]`/`[x]` strippen, Marker bleiben.                 |
| **lists**  | Indent / Dedent        | Ebenen-bewusst: jede Einrück-Ebene wird sauber neu nummeriert.      |
| **lists**  | Move lines             | Zeile/Auswahl hoch/runter + Reindent + Renumber.                    |
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
| `<Plug>(cascade-indent)`            | n, x  | Einrücken + ebenen-bewusst renumbern     |
| `<Plug>(cascade-dedent)`            | n, x  | Ausrücken + ebenen-bewusst renumbern     |
| `<Plug>(cascade-move-up)`           | n, x  | Zeile/Auswahl hoch + Renumber            |
| `<Plug>(cascade-move-down)`         | n, x  | Zeile/Auswahl runter + Renumber          |
| `<Plug>(cascade-renumber)`          | n     | Block neu nummerieren                    |
| `<Plug>(cascade-rotate-form)`       | n, x  | Block/Auswahl durch Formen rotieren      |
| `<Plug>(cascade-rotate-form-back)`  | n, x  | … rückwärts                              |
| `<Plug>(cascade-sort)`              | n, x  | Block/Auswahl A–Z sortieren              |
| `<Plug>(cascade-reverse)`           | n, x  | Block/Auswahl-Reihenfolge umkehren       |
| `<Plug>(cascade-strip-checkbox)`    | n, x  | Checkboxen im Block/Auswahl entfernen    |

> `<Tab>`/`<S-Tab>` sind bewusst **nicht** im Preset (Konflikt mit Completion).
> Bei Bedarf via `<Plug>(cascade-indent/dedent)` selbst binden.

### User commands

Range-aware — ohne Range wirken sie auf den Listenblock am Cursor, mit Range
(z. B. Visual `:'<,'>`) auf die Auswahl:

| Command                       | Wirkung                                            |
| ----------------------------- | -------------------------------------------------- |
| `:CascadeRotate [next\|prev]` | Form vor/zurück rotieren (`!` = rückwärts).        |
| `:CascadeSort`                | Block/Auswahl A–Z sortieren (`!` = Z–A).           |
| `:CascadeReverse`             | Reihenfolge umkehren.                              |
| `:CascadeStrip`               | Checkboxen entfernen.                              |
| `:CascadeIndent [n]`          | Einrücken (n Ebenen) + Renumber.                  |
| `:CascadeDedent [n]`          | Ausrücken (n Ebenen) + Renumber.                  |

Im Preset zusätzlich buffer-lokal (jeweils Normal **und** Visual):
`<leader>tf` / `<leader>tF` (Form vor/zurück), `<leader>ts` (Sort),
`<leader>tv` (umkehren), `<leader>tx` (Checkbox strippen).

**Global** (alle Filetypes) bindet das Preset zusätzlich:
- Einrücken/Ausrücken: `<A-Right>` / `<A-Left>` (Normal, Visual, Insert → `<C-t>`/`<C-d>`).
- Zeilen verschieben: `<A-Up>` / `<A-Down>` (Normal, Visual, Insert).

Beim Verschieben einer nummerierten Liste wird reindentiert und der Block neu
nummeriert (Text wandert, Nummern bleiben sequenziell). Außerhalb von Listen ist
es ein normales `:move` mit `==`-Reindent.

### Ebenen-bewusster Indent

Beim Ein-/Ausrücken einer nummerierten Liste wird **jede Einrück-Ebene** neu
nummeriert: eine tiefere Ebene startet bei `1.`, die Rückkehr auf eine flachere
Ebene läuft weiter, und die verlassene Ebene schließt ihre Lücke. `vim.v.count`
gibt die Anzahl Ebenen an. Außerhalb der Listen-Filetypes ist es ein normales
`>>`/`<<` — damit ersetzt es ein generisches Indent-Mapping vollständig.

```
1. top              1. top
  1. a       →        1. a
  2. b                2. b
  3. c  (>>)            1. c     ← neue Subebene startet bei 1.
  4. d                3. d       ← Lücke geschlossen (4→3)
  5. e                4. e       ← (5→4)
2. bot              2. bot
```

### Form-Rotation

Eine Aktion rotiert den **ganzen Block** (oder die Visual-Auswahl) durch die in
`lists.forms` konfigurierten Formen. „Nummerierung zu Checkbox" ist damit der
erste Rotationsschritt:

```
1. eins        ->   1. [ ] eins        ->   - [ ] eins        ->   - eins
2. zwei              2. [ ] zwei              - [ ] zwei              - zwei
```

Eine Form kombiniert eine Marker-Shape (`1.`, `-`, `a)`, `I.`) mit optionaler
`[ ]`-Checkbox. Bestehende Checkbox-Zustände (`[x]`) bleiben beim Rotieren
erhalten; geordnete Ziele werden automatisch neu nummeriert.

---

## Configuration

Defaults (Auszug — vollständige Referenz in `:h cascade-config`):

```lua
require("cascade").setup({
  lists = {
    enable = true,                           -- Master-Schalter Listen-Domäne
    features = {                             -- jedes Feature einzeln an/aus
      continue = true, checkbox = true, cycle_type = true,
      rotate = true, sort = true, reverse = true, strip = true,
      indent = true, move = true,
    },
    filetypes = { "markdown", "markdown.mdx", "text", "tex", "norg" },
    types = { "unordered", "digit" },        -- Erkennungs-Reihenfolge
    unordered_markers = { "-", "*", "+" },
    cycle = { "-", "*", "+", "1.", "a)", "I." },  -- cycle_type (eine Zeile)
    forms = { "1.", "1. [ ]", "- [ ]", "-" },     -- Form-Rotation (Block/Visual)
    checkbox = { states = { " ", "x" } },    -- N-Zustands-Cycle möglich
    continue = { delete_empty = true },
    renumber = {                             -- WANN automatisch neu nummeriert wird
      enable = true,
      on = { "edit" },                       -- "edit" = sofort, "save" = bei :w
    },
  },
  cycle = {
    enable = true,
    features = { word = true },              -- Wort/Boolean-Cycle an/aus
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

**Renumber-Timing:** `lists.renumber.on` steuert, *wann* nummeriert wird —
`{ "edit" }` (sofort nach Indent/Move/Continue/…), `{ "save" }` (beim `:w` über
`BufWritePre`, der ganze Buffer) oder beides `{ "edit", "save" }`. `enable = false`
schaltet alles ab — dann nummeriert nur noch manuell `:CascadeRenumber` /
`<leader>tr`. Ein einfacher Bool wird weiter akzeptiert (`true` = `{ "edit" }`).

**Feature-Toggles:** Jedes Feature lässt sich über `lists.features.*` bzw.
`cycle.features.*` einzeln abschalten. Ein deaktiviertes Feature führt seine
Aktion nicht mehr aus und das Preset bindet seine Tasten nicht — Tasten mit
nativer Bedeutung (`<CR>`, `<A-Right>`, `<C-a>`) bleiben dann nativ. `:checkhealth
cascade` zeigt den Status. Fehlende Einträge gelten als aktiviert.

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

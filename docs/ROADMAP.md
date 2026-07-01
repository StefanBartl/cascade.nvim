# Roadmap

Geplante Erweiterungen über den aktuellen Funktionsumfang hinaus. Reihenfolge
ist grob nach Wert/Aufwand, nicht verbindlich.

## Lists

- ~~**Ebenen-bewusster Indent + Renumber**~~ — ✅ erledigt: `<A-Right>`/`<A-Left>`,
  `:CascadeIndent`/`:CascadeDedent`, Normal + Visual, `count` = Ebenen, mit
  Per-Level-Renumber (`renumber.tree`).
- **Subtree-aware indent** — beim Ein-/Ausrücken Kind-Items (tiefer eingerückte
  Folgezeilen) automatisch mitnehmen (aktuell wird nur die/ die markierten
  Zeile(n) geshiftet, Kinder bleiben stehen).
- **Loose-List-Support** — Items mit Leerzeilen dazwischen als ein Block
  behandeln (aktuell beendet eine Leerzeile den Block fürs Renumbern).
- **Start-Offset auf Subebenen erhalten** — Tree-Renumber setzt Subebenen
  immer auf `1`; ein bewusster Nicht-1-Start auf tieferen Ebenen geht verloren.
- ~~**Visual-Mode-Operationen**~~ — ✅ erledigt: Form-Rotation (`:CascadeRotate`),
  Sort A–Z (`:CascadeSort`), Reihenfolge umkehren (`:CascadeReverse`) und
  Checkbox entfernen (`:CascadeStrip`) auf Block + Visual.
- **`gq`/`textwidth`-Awareness** — Fortführung respektiert Umbruch und hängende
  Einrückung (hanging indent).
- **Mehr-Zeichen-Checkbox-States** — aktuell sind States Ein-Zeichen (`[ ]`);
  Support für `[~]`, Worte oder Symbole >1 Zeichen.
- **Per-Filetype Marker-Patterns** — eigene Lua-Patterns je Filetype
  (neorg/latex_item bereits über `types` adressierbar, aber nicht frei custom).

## Cycle

- **Datums-Increment** — `2024-01-31` + Tag/Monat/Jahr unter dem Cursor.
- **Operator-Flips** — `==`↔`!=`, `&&`↔`||`, `<`↔`>`, `+`↔`-`.
- **Telescope/Picker** — Cycle-Gruppe interaktiv auswählen statt nur vor/zurück.

## Querschnitt

- **Treesitter-optionaler Präzisionsmodus** — opt-in, nur wo echte
  Syntax-Semantik gebraucht wird; Default bleibt reiner Zeilen-Scan.
- ~~**Test-Suite**~~ — ✅ erledigt: `docs/TESTS/` mit Runner (`run.lua`),
  Harness und Specs (units/lists/cycle/commands); `scripts/smoke.lua` ist nur
  noch ein dünner Kompatibilitäts-Shim.
- **vim-repeat-Interop** — neben dem operatorfunc-Trick optional
  `repeat#set` nutzen, wenn vorhanden.

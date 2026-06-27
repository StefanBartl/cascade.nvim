# Roadmap

Geplante Erweiterungen über den aktuellen Funktionsumfang hinaus. Reihenfolge
ist grob nach Wert/Aufwand, nicht verbindlich.

## Lists

- **Subtree-aware indent** — beim Ein-/Ausrücken Kind-Items (tiefer eingerückte
  Folgezeilen) automatisch mitnehmen.
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
- **Test-Suite** — `scripts/smoke.lua` zu einer vollständigen busted/mini.test
  Suite ausbauen (marker/roman/alpha sind reine Funktionen → trivial testbar).
- **vim-repeat-Interop** — neben dem operatorfunc-Trick optional
  `repeat#set` nutzen, wenn vorhanden.

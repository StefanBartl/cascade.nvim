# Roadmap

Geplante Erweiterungen über den aktuellen Funktionsumfang hinaus. Reihenfolge
ist grob nach Wert/Aufwand, nicht verbindlich.

## Lists

- **Subtree-aware indent** — beim Ein-/Ausrücken Kind-Items (tiefer eingerückte
  Folgezeilen) automatisch mitnehmen (aktuell wird nur die/ die markierten
  Zeile(n) geshiftet, Kinder bleiben stehen).
- **Renumbering-Marker (Anchors)** — explizite, nicht im Dokument stehende
  Marker, die eine Blockgrenze unabhängig von der Struktur erzwingen.
  Konzept + Bewertung: [renumbering_markers.md](ROADMAP/renumbering_markers.md)
  (zurückgestellt, bis der Restbedarf nach `blank_break` feststeht).
- **Start-Offset auf Subebenen erhalten** — Tree-Renumber setzt Subebenen
  immer auf `1`; ein bewusster Nicht-1-Start auf tieferen Ebenen geht verloren.
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
- **vim-repeat-Interop** — neben dem operatorfunc-Trick optional
  `repeat#set` nutzen, wenn vorhanden.

## Qualität & Checklist-Audits

cascade wurde gegen die drei persönlichen Lua/Neovim-Checklisten auditiert. Die
Ergebnisse und bewussten Abweichungen sind dokumentiert in:

- [Arch&Coding.md](ROADMAP/Arch&Coding.md) — Architektur- & Coding-Regeln
- [Zentral-Prinzipien.md](ROADMAP/Zentral-Prinzipien.md) — zentrale Modul-Prinzipien
- [Checklist.md](ROADMAP/Checklist.md) — Master-Checklist (Schnell-Check/PR/Coding)
- [NEOTREE_FEATURES.md](ROADMAP/NEOTREE_FEATURES.md) — Filetree-Audit (Ergebnis: keine)
- [renumbering_markers.md](ROADMAP/renumbering_markers.md) — Konzept: persistente Renumbering-Anker

**Bilanz:** überwiegend erfüllt; die verbleibenden Punkte sind niedrig-prior und
optional:

- **Debug-Schalter** (Zentrale-Prinzipien §9, optional) — `cascade.debug = true`
  + `lib`-basiertes Logging; nur bei Bedarf.
- **Bewusst abweichend (kein Handlungsbedarf):** kein `safe_call`-Envelope
  (direktes `pcall`), funktionaler Stil statt Metatables, README englisch
  (publiziertes Plugin, kein Config-Modul).

# Roadmap

Geplante Erweiterungen über den aktuellen Funktionsumfang hinaus. Reihenfolge
ist grob nach Wert/Aufwand, nicht verbindlich.

## Lists

- **Renumbering-Marker (Anchors)** — explizite, nicht im Dokument stehende
  Marker, die eine Blockgrenze unabhängig von der Struktur erzwingen.
  Konzept + Bewertung: [renumbering_markers.md](ROADMAP/renumbering_markers.md)
  (zurückgestellt, bis der Restbedarf nach `blank_break` feststeht).

## Qualität & Checklist-Audits

cascade wurde gegen die drei persönlichen Lua/Neovim-Checklisten auditiert.
Die Audits gegen Arch&Coding-Regeln, die Master-Checklist und den
Filetree-Feature-Katalog sind **abgeschlossen und erfüllt** (keine offenen
Punkte) — die entsprechenden Dateien wurden entfernt. Verbleibend:

- [Zentral-Prinzipien.md](ROADMAP/Zentral-Prinzipien.md) — der eine noch
  offene, niedrigpriore Punkt (Hot-Path-Allokationen).
- [renumbering_markers.md](ROADMAP/renumbering_markers.md) — Konzept:
  persistente Renumbering-Anker (zurückgestellt).

**Bewusst abweichend (kein Handlungsbedarf, dauerhaft):** kein `safe_call`-
Envelope (direktes `pcall`), funktionaler Stil statt Metatables, README
englisch (publiziertes Plugin, kein Config-Modul).

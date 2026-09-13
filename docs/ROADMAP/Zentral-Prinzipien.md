# Zentrale Prinzipien — offene Punkte für cascade.nvim

> Auszug aus dem Audit gegen die Checkliste [Zentrale-Prinzipien](file:///E:/repos/Notes/MyNotes/Checklists/Lua/Zentrale-Prinzipien.md).
> Alle erfüllten Punkte (Events, Lazy-Loading, Kontext-Bündelung, Autocommand-
> Gruppen, Event-vs-Command, Treesitter-Entscheidung, Cache, Laufzeit-Fokus,
> Debugbarkeit) wurden entfernt — Audit dafür abgeschlossen. Verbleibt ein
> niedrigpriorer, optionaler Punkt:

## 8. Allokationen im Hot-Path vermeiden — ⚠️

- Hot-Path (ein Tastendruck) ist kurz; Renumber-Schreibvorgänge laufen bereits in
  ein einziges `nvim_buf_set_lines` gebündelt (Commit `11988ca`).
- Kleinere Closures pro Aktion (z. B. in `dispatch.try`) sind bewusst akzeptiert:
  cascade läuft nie in `CursorMoved`/`TextChanged`, daher kein echter Hot-Loop.
- **Kein offener Handlungsbedarf**, aber als Punkt notiert falls je ein
  häufig-getriggerter Pfad hinzukommt.

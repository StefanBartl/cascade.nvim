# Zentrale Prinzipien — Audit für cascade.nvim

> Anwendung der Checkliste [Zentrale-Prinzipien](file:///E:/repos/Notes/MyNotes/Checklists/Lua/Zentrale-Prinzipien.md)
> auf cascade.nvim. Pro Prinzip: Status + Belege im Code. cascade wurde bewusst
> nach genau diesen Prinzipien entworfen, daher ist die Bilanz überwiegend grün.

Legende: ✅ erfüllt · ⚠️ teilweise / bewusst abgewogen · ❌ offen

## Vorbemerkung: `lib`-Nutzung

Die Checkliste fordert die `lib.*`-Library (`lib.notify`, `lib.map`, `lib.augroup`,
…). cascade nutzt sie als **soft dependency** über die geguardete Bridge
[`util/lib.lua`](../../lua/cascade/util/lib.lua): ist `lib.nvim` vorhanden, laufen
`map`/`notify`/`augroup` durch `lib`; sonst native Fallbacks (Standalone-Betrieb).
Das ist Absicht — ein publiziertes Plugin darf keine harte Abhängigkeit auf die
persönliche Library haben. ⚠️ Abgewogen (bewusst weicher als die Checkliste, die
von Modulen *innerhalb* der Config ausgeht).

| Bereich | lib-Wrapper | Status |
| --- | --- | --- |
| Keymaps | `lib.map` (Fallback `vim.keymap.set`) | ✅ |
| Autocmd-Gruppe | `lib.augroup` (Fallback `nvim_create_augroup`) | ✅ |
| Notify | `lib.notify` (Fallback `vim.notify`) | ✅ (aktuell nicht genutzt — cascade notifyt nicht) |
| `lib.cross` / memo / lazy / hover_select | — | n/a bzw. eigene Lösung (siehe unten) |

## 1. Events bündeln, Logik entkoppeln — ✅

- Nur **zwei** Autocmds im ganzen Plugin: `FileType` (buffer-lokale Listen-Keys)
  und `BufWritePre` (Renumber-on-save), beide in
  [`bindings/autocmds.lua`](../../lua/cascade/bindings/autocmds.lua).
- Keine Mehrfachbindung an dasselbe Event; die Aktionen laufen über direkte
  Keymaps auf die Facade-Funktionen (`bindings/keymaps.lua`), nicht über
  Event-Streuung.

## 2. Eigene Logik lazy laden — ✅

- `setup()` definiert nur Keymaps (falls `keymaps.preset = true`) + Commands;
  schwere Arbeit passiert erst beim Tastendruck. Empfohlene Installation:
  `event = "VeryLazy"` + `ft`.
- `require`s der Feature-Module sind top-of-file, aber die Module sind klein und
  reine Funktionssammlungen; kein Laden von ungenutztem State beim Startup.

## 3. Kontext statt Mehrfach-API-Zugriffe — ✅

- Zentrales [`core/context.lua`](../../lua/cascade/core/context.lua): **ein**
  `CascadeContext` (bufnr, row0, col0, line, ft) pro Aktion, statt wiederholter
  `nvim_buf_get_*`/`vim.fn.*`-Abfragen.

## 4. Autocommand-Gruppen sauber nutzen — ✅

- Beide Autocmds hängen an klar benannten, bei jedem `setup()` geleerten Gruppen
  (`cascade_list_keymaps`, `cascade_renumber_save`) → Reload ohne Neustart sauber.

## 5. Event oder Command? — ✅

- Nahezu alles ist **explizit** (Tasten/`:Cascade*`-Commands), nicht automatisch.
  Das einzige zustandsgetriebene Event (`BufWritePre`-Renumber) hängt an
  `lists.renumber.on`, das per Default sowohl `"edit"` als auch `"save"`
  enthält — abschaltbar über `lists.renumber.enable = false` oder ein
  engeres `on`. Grund für den Default-Wechsel: `"edit"` feuert nur bei
  cascade-eigenen Aktionen (indent/move/continue/…); Text, der direkt mit
  zwei `1.`-Markern getippt oder eingefügt wird, löst nie ein Edit-Event
  aus und blieb ohne `"save"` als Sicherheitsnetz dauerhaft unrenumbert.

## 6. Treesitter notwendig oder nicht? — ✅

- **Kein Treesitter.** Reiner Zeilen-Scan + memoisierte Vim-Patterns
  ([`core/patterns.lua`](../../lua/cascade/core/patterns.lua)). Ein optionaler
  TS-Präzisionsmodus ist in der ROADMAP als opt-in vorgemerkt.

## 7. Cache vorhanden und explizit? — ✅

- Pattern-Kompilierung ist memoisiert (Key = markers concat). Regenerierbar,
  kein persistenter Cache nötig (nichts gehört nach `stdpath("cache")`).

## 8. Allokationen im Hot-Path vermeiden — ⚠️

- Hot-Path (ein Tastendruck) ist kurz; Renumber-Schreibvorgänge wurden bereits in
  ein einziges `nvim_buf_set_lines` gebündelt (Commit `11988ca`).
- Kleinere Closures pro Aktion (z. B. in `dispatch.try`) sind bewusst akzeptiert:
  cascade läuft nie in `CursorMoved`/`TextChanged`, daher kein echter Hot-Loop.
- **Kein offener Handlungsbedarf**, aber als Punkt notiert falls je ein
  häufig-getriggerter Pfad hinzukommt.

## 9. Debugbarkeit eingeplant? — ⚠️

- `:checkhealth cascade` zeigt Domänen-/Feature-/lib-Status; Testsuite unter
  `docs/TESTS/` erlaubt isoliertes Testen jeder reinen Funktion.
- **Kein dedizierter Debug-Schalter/Log** (z. B. `cascade.debug = true`). Optionaler
  nächster Schritt, falls Bedarf — bisher nicht nötig, da Kontrollfluss (detect →
  advance → fallback) einfach nachvollziehbar ist.

## 10. Laufzeit wichtiger als Startup? — ✅

- Es läuft **kein** Code bei `CursorMoved`/`TextChanged`/`BufEnter`. Arbeit
  passiert nur auf explizite Aktion → keine häufigen Events, kein Overhead.

---

## Fazit

cascade erfüllt die zentralen Prinzipien weitgehend by design. Zwei bewusst
offene, niedrigpriore Punkte:

1. **Debug-Schalter** (Prinzip 9) — optionales `debug`-Flag + `lib`-basiertes
   Logging, falls künftig gebraucht.
2. **Hot-Path-Allokationen** (Prinzip 8) — nur relevant, falls je ein
   häufig-getriggerter Codepfad hinzukommt; aktuell kein Problem.

Beides ist in [ROADMAP.md](../ROADMAP.md) nicht kritisch und wird nur bei Bedarf
umgesetzt.

# Lua/Neovim Master-Checklist — Audit für cascade.nvim

> Anwendung der [Checklist](file:///E:/repos/Notes/MyNotes/Checklists/Lua/Checklist.md)
> auf cascade.nvim. Die umfangreichen Kapitel zu **Sortier-/Such-Algorithmen,
> Datenstrukturen (Bäume/Heaps/Filter/Tries) und Bit-Operationen** sind für ein
> zeilenbasiertes Text-Plugin **n/a** (siehe Ende). Fokus hier: Schnell-Check,
> PR-Review, Coding-Checkliste, Anti-Patterns, Struktur.

Legende: ✅ · ⚠️ bewusste Abweichung · n/a

## Schnell-Check (10 Punkte, vor jedem Merge)

| Prüfschritt | Prio | Status | Beleg |
| --- | --- | --- | --- |
| Fehlerbehandlung (pcall, keine stillen Fehler) | 🔴 | ✅ | `pcall` um alle Buffer-Mutationen; Handler geben `false` → nativer Fallback. |
| Type Guards (type/nil vor API) | 🔴 | ✅ | `type()`-Checks + `Context.writable()` vor Edits. |
| Buffer/Window validieren | 🔴 | ✅ | `Context.writable(bufnr)`; keine Fenster. |
| Keine globalen States | 🔴 | ✅ | Nur `config.options`, Zugriff via `get(path)`; kein `_G.*`. |
| Single Responsibility | 🔴 | ✅ | Ein Modul = ein Zweck (marker/renumber/indent/move/…). |
| UI-Cleanup | 🟡 | n/a | Keine UI/Fenster zu bereinigen. |
| Performance-Hotspots (concat/reserve) | 🟡 | ✅ | Renumber: Zeilen sammeln → ein `set_lines`; Patterns memoisiert. |
| Annotationen vollständig | 🟡 | ✅ | `@module/@brief/@description` + `@param/@return`; Aliase in `@types`. |
| Testbarkeit (pure functions) | 🟡 | ✅ | Reine Funktionen; `docs/TESTS/` Suite. |
| Import-Reihenfolge | 🟢 | ✅ | Kern/Config → Feature-Module → Bindings. |

### Bonuspunkt: `lib`-Modul — ✅ (soft)

`lib.map`/`lib.notify`/`lib.augroup` via geguardete Bridge `util/lib.lua` (Fallback
nativ). Bewusst **soft**, weil publiziertes Plugin ohne harte Abhängigkeit auf die
persönliche Library. `lib.cross`/`memo`/`lazy`/`hover_select`: cascade braucht sie
nicht (cross-platform durch reinen Zeilen-Scan; eigene Pattern-Memoization).

## PR-Review-Checkliste

### 1. Sicherheit & Fehlerbehandlung — ✅ / ⚠️
- pcall/Guards/explizite Rückgaben/kein Low-Level-notify: ✅
- `safe_call`-Envelope + strukturierte Fehlertypen: ⚠️ bewusst nicht — direktes `pcall`, keine Error-Objekte im Scope.

### 2. Modularität & Struktur — ✅
- SRP ✅, keine Globals ✅, reine Funktionen ✅, interne Helfer lokal ✅.
- Registry: keine `<Plug>`-Indirektion mehr — Keymaps binden direkt auf die Facade-Aktionen in `bindings/keymaps.lua` ✅.
- `/config`-Ordner mit `DEFAULTS.lua`: ✅ (`config/{init,DEFAULTS}.lua`).

### 3. Buffer-/Window-Management — ✅ (Fenster n/a)
- Handle-zuerst-binden + Gültigkeit via `writable()` ✅.
- Race Conditions / Defer-Revalidierung: n/a — cascade nutzt **kein** `vim.defer_fn`/async; alle Edits synchron im Tastendruck.

### 4. UI-State-Management — n/a
Kein UI-State (keine Fenster/Floats).

### 5. Dokumentation & Annotationen — ✅
Kopf-Tags ✅, Funktions-Tags ✅, Aliase/Felder in `@types` ✅, `#`-Kommentar-Konvention eingehalten ✅.

### 6. Testbarkeit & Lesbarkeit — ✅
Pure Functions ✅, Test-Entry `docs/TESTS/run.lua` ✅. DI: Config wird als `opts` durchgereicht (kein Hard-Wiring) ✅.

### 7. Tooling — ✅
- Lua LS: `.luarc.json` vorhanden (`diagnostics.globals=vim`, workspace.library) ✅.
- Formatter/Linter im CI: ✅ `.github/workflows/ci.yml` — `stylua --check`, `luacheck`, headless `docs/TESTS/run.lua` (Configs `stylua.toml`, `.luacheckrc`).

## Coding-Checkliste

- **A. Strings & Tabellen** — ✅ kein Concat im Loop (table + `concat`/`set_lines`). Inline-Reserve/`t[i]` nicht nötig (kleine, kurze Arrays).
- **B. Performance-Quickwins** — ✅ Memoization vorhanden; async/uv n/a (keine Hintergrund-Tasks); Debounce n/a (synchron).
- **C. Neovim-API sicher** — ✅ Guards; Deferred Calls n/a.
- **D. State-/Datenmodelle** — Getter via `config.get`; Metatables/FIFO n/a.
- **E. GC bewusst steuern** — n/a (keine großen Objekte/Coroutinen).
- **F. Lazy-Loading** — ✅ empfohlene Installation `event="VeryLazy"`+`ft`; `setup()` bindet nur, arbeitet nicht.

## Anti-Pattern-Check — ✅
Kein globaler State ✅, keine API ohne Guards ✅, kein String-Concat im Loop ✅, keine Closures im Hot-Loop (kein Hot-Loop) ✅, keine Flut kleiner Temp-Tabellen ✅.

## Import- & Dateistruktur-Check — ✅
Import-Reihenfolge ✅, Datei-Header ✅, projektweiter `@types`-Ordner ✅.

## Performance-Spickzettel — ✅ / n/a
`table.concat`/gebündelte Writes ✅; Weak-Caches, Async/uv, Debounce: n/a für den synchronen, kleinen Scope.

## Sort / Datenstrukturen / Bit-Ops — n/a (mit einer Ausnahme)

cascade implementiert **keine** eigenen Bäume, Heaps, Filter, Tries oder
Bit-Tricks → diese Kapitel sind n/a. **Einzige Ausnahme:** das A–Z-Sortieren von
Listenzeilen (`lists/transform.sort`) nutzt Lua's `table.sort` (Standardbibliothek
— Checkliste: „Standardbibliothek bevorzugen" ✅). Stabilität ist irrelevant, da
ganze Zeilen als Schlüssel verglichen werden; Renumber läuft danach separat.

## Reviewer-Notizen

| Bereich | Beobachtung | Empfehlung |
| --- | --- | --- |
| Sicherheit | pcall + Guards durchgängig, keine stillen Fehler | keine |
| Modularität | SRP, keine Globals, funktional | keine |
| Neovim-API | synchron, keine ungeprüften Handles | keine |
| Performance | memoisiert, gebündelte Writes, keine Hot-Loops | keine |
| Doku/Annotation | vollständig, `@types` zentral + Subdir-Anker | keine |
| Tests | `docs/TESTS/` Suite grün | optional: mehr Randfälle |
| checkhealth-Modul? | ✅ `:checkhealth cascade` (Domänen/Features/lib/which-key) | keine |

---

## Fazit & Plan

cascade erfüllt die Master-Checklist in allen für ein Text-Plugin relevanten
Punkten. **Bewusste Abweichungen:** kein `safe_call`-Envelope, funktionaler Stil
(§1/§4-analog). Der zuvor offene CI/Tooling-Punkt (§7) ist umgesetzt:
`.github/workflows/ci.yml` (stylua/luacheck/headless Tests). Keine offenen
„empfohlen"-Punkte mehr.

## Literatur und Referenzen

- [Arch&Coding.md](./Arch&Coding.md) · [Zentral-Prinzipien.md](./Zentral-Prinzipien.md)
- Quell-Checklisten: `E:/repos/Notes/MyNotes/Checklists/Lua/`

# Architektur- & Coding-Regeln — Audit für cascade.nvim

> Anwendung der Checkliste [Arch&Coding-Regeln](file:///E:/repos/Notes/MyNotes/Checklists/Lua/Arch&Coding-Regeln.md)
> auf cascade.nvim. Nur die **normativen** Abschnitte (§1–11 + Annotationen/
> Naming/Types) sind hier auditiert; die CPU-/Table-/String-Benchmark-Kapitel
> sind Referenzmaterial ohne Einzel-Check.

Legende: ✅ erfüllt · ⚠️ bewusste Abweichung · ❌ offen · n/a nicht zutreffend

## §1 Sicherheitsprinzipien & Fehlerbehandlung — ✅ (2 bewusste Abweichungen)

| Regel | Status | Beleg / Anmerkung |
| --- | --- | --- |
| `pcall` bevorzugt | ✅ | Alle Buffer-Mutationen laufen unter `pcall` (`renumber.tree/all`, `dispatch.try`). |
| Type Guards & Literal Checks | ✅ | `type(...) ~= "table"`, `~= nil`, `writable()`-Guards vor API-Zugriffen. |
| Explizite Rückgaben | ✅ | Handler geben `boolean handled` zurück (detect→advance→fallback), keine stillen Fehler. |
| Kein `notify()` in Low-Level | ✅ | cascade notifyt gar nicht; `lib.notify`-Bridge existiert nur als Fallback. |
| `safe_call`-Wrapper `{ok,result,err}` | ⚠️ | Nicht verwendet — cascade nutzt direktes `pcall`. Für den Scope (kurze, synchrone Buffer-Edits) ausreichend; ein `{ok,…}`-Envelope wäre Overhead ohne Nutzen. |
| Strukturierte Fehlertypen | ⚠️/n/a | Keine Error-Objekte — Fehler sind „Aktion greift nicht" → `false` + nativer Fallback. Kein Bedarf. |
| `@error`/`@raises` Tags | n/a | Checkliste selbst: „nur mit gutem Grund" (lua_ls kennt sie nicht). Keine raising API. |
| Private Funktionen lokal | ✅ | Interne Helfer sind `local function`; nur die Fassade exportiert. |
| Argumente typisiert übergeben | ✅ | Durchgängige `@param`-Annotationen. |

## §2 Modularisierung & Strukturprinzipien — ✅

| Regel | Status | Beleg |
| --- | --- | --- |
| Modul = eine Verantwortung | ✅ | `lists/{marker,renumber,indent,move,checkbox,cycle_type,roman,alpha,transform}`, `cycle/{token,word_cycle}`, `core/{context,patterns}` — je ein Zweck. |
| Reine Funktionen bevorzugen | ✅ | `roman`, `alpha`, `marker.parse/advance/render` sind seiteneffektfrei (direkt testbar). |
| Lokale statt globale Funktionen | ✅ | Keine globalen Funktionen. |
| Entwurfsmuster wenn sinnvoll | ✅ | „Facade" (`init.lua`) + „Chain of Responsibility" (`dispatch.try`). |
| Tools via Registry | n/a | cascade hat keine Tool-Registry; `PLUGS`-Tabelle ist die zentrale Binding-Registry. |
| Keine globalen States | ✅ | Einziger State ist die gemergte Config (`config.options`), Zugriff nur über `get(path)`. |

## §3 Buffer- & Window-Management — ✅ (Fenster n/a)

- cascade öffnet **keine** Fenster/Floats → der halbe Abschnitt (UI-State, `cleanup_all`, `open/close_window`) ist n/a.
- Buffer: `Context.writable(bufnr)` guardet vor Mutationen; Edits laufen unter `pcall`. ✅
- Kleiner Feilpunkt: statt `nvim_buf_is_valid` wird über `writable()` (modifiable + listed) geguardet — funktional äquivalent für den Zweck. ✅

## §4 Methoden, Metatables & Datenmodelle — n/a (bewusst funktional)

cascade ist **funktional**, nicht OO: keine Metatables, kein `__index`, keine Getter/Setter-Objekte. Das ist für ein zustandsarmes Text-Plugin die einfachere, testbarere Wahl. Kein Handlungsbedarf.

## §5 Dokumentation & Annotationen — ✅ (2 bewusste Abweichungen)

| Regel | Status | Beleg / Anmerkung |
| --- | --- | --- |
| Datei-Tags `@module/@brief/@description` | ✅ | Jede Quelldatei trägt den Header. |
| Kommentare pro Funktion `@param/@return` | ✅ | Durchgängig, inkl. `@return nil`. |
| Konsistentes englisches Naming | ✅ | snake_case, englisch. |
| Explizite Typisierungen `@alias/@field` | ✅ | Vollständig in `@types/init.lua` (`CascadeConfig`, `CascadeMarker`, …). |
| Modulverlinkung `@see` | ✅ | z. B. `util/lib.lua` → `@see lib-nvim-dependency`. |
| **`/types`-Ordner pro Subverzeichnis** | ✅ | Konvention gewahrt: `lists/types/init.lua` und `cycle/types/init.lua` existieren als Anker-Stubs (`return {}`) und verweisen auf das zentrale `@types/init.lua`, in dem die geteilten Typen gebündelt liegen. |
| **README deutsch + `doc/*.txt` englisch** | ⚠️ | Diese Regel gilt für **`nvim/config`-Module**. cascade ist ein **publiziertes Standalone-Plugin** → README **englisch** (Konvention für veröffentlichte Plugins). Bewusst abweichend. |

## §6 Testbarkeit & Lesbarkeit — ✅

| Regel | Status | Beleg |
| --- | --- | --- |
| Klein & fokussiert (SRP) | ✅ | siehe §2. |
| Klarheit vor Kürze | ✅ | Ausführliche Kommentare, sprechende Namen. |
| Testbarkeit durch Design | ✅ | Keine Hardcoded States; reine Funktionen. |
| Separater Test-Entry | ✅ | `docs/TESTS/run.lua` + `harness.lua` + 4 Specs. |
| Snapshot/Restore | n/a | Kein langlebiger State zum Snapshotten. |

## §7 Fehlerbehandlung & Validierung — ⚠️ (wie §1)

`safe_call`/strukturierte Fehlertypen bewusst nicht verwendet — direktes `pcall` deckt den synchronen, kurzen Scope ab. Kein offener Bedarf.

## §8 Performance & Speicher — ✅

| Regel | Status | Beleg |
| --- | --- | --- |
| Debounced/gesammelte Writes | ✅ | Renumber schreibt gebündelt in **ein** `nvim_buf_set_lines` (Commit `11988ca`). |
| Lokale Variablen | ✅ | Module cachen `require`-Referenzen top-of-file. |
| Memoization | ✅ | `core/patterns.lua` memoisiert kompilierte Marker-Patterns. |
| String-Concat in Loops vermeiden | ✅ | Zeilen werden in einer Tabelle gesammelt, dann `set_lines` — kein `s..s` im Loop. |
| Weak-Tables / GC-Steuerung | n/a | Keine langlebigen/großen Caches → keine Weak-Tables nötig. |

## §9–§11 Cache / Weak Tables / Spezialfälle — n/a

Kein persistenter Cache, keine Dual-Representation, keine FIFO/History-Strukturen. Die einzige Memoization (Patterns) ist regenerierbar und klein.

## Import-Reihung & Alias-Regeln — ✅

- Requires folgen grob der vorgegebenen Reihung (Kern/Config → State/Feature-Module → Bindings). ✅
- Lokale Aliase für heiße Pfade: nicht nötig (keine tight loops über 1M Calls). ✅

---

## Fazit & Plan

cascade folgt den Regeln stark. **Bewusste Abweichungen** (kein Handlungsbedarf, dokumentiert):

1. **Kein `safe_call`/Error-Envelope** (§1/§7) — direktes `pcall` genügt dem Scope.
2. **Funktionaler Stil statt Metatables** (§4) — testbarer für ein Text-Plugin.
3. **README englisch** (§5) — Plugin ist veröffentlicht, nicht Config-Modul.

**Kein offener Angleich nötig** — alle übrigen Konventionen (inkl. `/types`-Anker
pro Subverzeichnis) sind gewahrt.

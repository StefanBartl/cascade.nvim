# Renumbering-Marker (Anchors) — Konzept

> **Status:** Entwurf, nicht implementiert. Bewusst zurückgestellt, bis sich
> zeigt, ob der neue `lists.renumber.blank_break`-Default den Bedarf nicht
> ohnehin schon deckt (siehe [Abgrenzung](#abgrenzung-brauchen-wir-das-überhaupt)).

## Motivation

Renumbering leitet die Blockgrenzen heute rein **strukturell** aus dem Text ab:
Marker-Zeilen, Einrückung, Leerzeilen (`lists.renumber.blank_break`). Das deckt
den Normalfall ab, aber nicht den Fall, in dem der Autor eine Grenze **anders
setzen will als die Struktur sie hergibt** — etwa zwei inhaltlich getrennte
Listen, die ohne Leerzeile direkt aufeinander folgen, oder umgekehrt eine
Liste, die trotz einer Leerzeile als ein Strang weiterlaufen soll.

Gewünscht ist ein **visueller Marker**, den der Nutzer setzt und der sagt:
„ab hier neu nummerieren, egal was die Struktur ergibt".

## Anforderungen

1. **Nicht im Dokument** — der Marker darf den Dateiinhalt nicht verändern
   (keine Kommentar-Token, keine Zero-Width-Zeichen, keine Diff-Artefakte).
2. **Geräteübergreifend** — dieselbe Datei auf einem zweiten Rechner mit
   derselben Neovim-/cascade-Konfiguration muss identisch nummerieren.
3. **Editier-stabil** — der Marker muss an seiner inhaltlichen Stelle bleiben,
   auch wenn darüber Zeilen eingefügt oder gelöscht werden.
4. **Sichtbar** — als Sign oder Virtual Text erkennbar, sonst unbedienbar.

Anforderung 1 und 2 stehen in direktem Konflikt: das Einzige, was garantiert
mit einer Datei mitreist, ist die Datei selbst. Jede Lösung ohne
In-Dokument-Token braucht deshalb einen **zweiten Sync-Kanal** — und der ist
der eigentliche Knackpunkt des Designs.

## Kernerkenntnis: zwei orthogonale Probleme

Marker-Systeme werden meist als *ein* Problem entworfen und scheitern daran.
Es sind zwei, und sie sind unabhängig voneinander lösbar:

| | Frage | Entscheidet über |
| --- | --- | --- |
| **(A) Speicherort** | Wo liegt die Marker-Datei? | ob es synct |
| **(B) Verankerung** | Woran hängt der Marker? | ob er nach Edits noch stimmt |

**(B) ist das schwierigere Problem.** Ein Marker, der als Zeilennummer
gespeichert ist, ist nach dem nächsten `O` drei Zeilen darüber falsch — egal
wie perfekt der Sync ist. Ohne belastbares Anchoring ist das Feature
frustrierend, unabhängig von allen anderen Design-Entscheidungen.

## (B) Verankerung

Drei Ebenen, die zusammenspielen müssen:

### Zur Laufzeit: Extmarks

`nvim_buf_set_extmark` ist exakt dafür gebaut — Neovim verschiebt Extmarks bei
jedem Edit korrekt mit, inklusive Undo. Innerhalb einer Session ist das Problem
damit vollständig gelöst. Extmarks sterben aber beim Buffer-Close; sie sind die
Laufzeit-Repräsentation, nicht der Speicher.

### Beim Speichern: Content-Fingerprint

Persistiert wird **nicht die Zeilennummer**, sondern ein Fingerprint des
Inhalts an der Ankerstelle:

- Text der Ankerzeile (normalisiert: Whitespace kollabiert, Marker-Präfix
  abgetrennt — sonst invalidiert das Renumbern selbst den Anker)
- optional 1–2 Nachbarzeilen als Disambiguierung bei Duplikaten
- die letzte bekannte Zeilennummer als *Hint* für die Suchreihenfolge, nicht
  als Wahrheit

### Beim Laden: Re-Anchoring

Fingerprint im Buffer suchen (beginnend beim Hint, dann nach außen), Extmark
neu setzen. Nicht mehr auffindbare Anker werden still verworfen oder als
`orphaned` gemeldet — nie geraten.

> Das ist dasselbe Verfahren, mit dem GitHub PR-Kommentare oder Google-Docs-
> Kommentare an Textstellen hängen. Bewährt, aber nicht trivial: Duplikate,
> Umformulierungen und großflächige Umstellungen sind echte Grenzfälle.

## (A) Speicherort

| Ort | Synct mit | Bewertung |
| --- | --- | --- |
| `stdpath("data")/cascade/` | — | gerätelokal; verletzt Anforderung 2 |
| Neovim-Config (`nvim/lua/plugins/cascade_nvim/marker/`) | Dotfiles-Repo | ✗ siehe unten |
| **`<git-root>/.cascade/markers.json`** | **dem Dokument** | ✓ empfohlen |
| `<datei>.cascade` neben der Datei | dem Dokument | maximale Lokalität, aber Datei-Zoo |
| Git-Notes / eigene Ref | Repo | exotisch, bricht außerhalb von Git |
| Zero-Width-Unicode im Dokument | dem Dokument | steht *doch* im Dokument, verseucht Diffs — ausgeschlossen |

### Warum nicht in die Neovim-Config

Naheliegend, weil die Dotfiles ohnehin synchronisiert werden — aber zwei
konkrete Schwächen:

- **Zwei Sync-Kanäle, die auseinanderlaufen.** Die Marker synchronisieren über
  das Config-Repo, die markierten Dokumente über ein *anderes* Repo. Wer das
  Dokument pusht und die Dotfiles vergisst, hat auf dem zweiten Gerät veraltete
  oder fehlende Marker. Umgekehrt genauso.
- **Absolute Pfade als Schlüssel.** `C:\repos\foo\notes.md` gegen
  `/home/stefan/repos/foo/notes.md` — der Key matcht nicht. Lösbar durch
  Normalisierung relativ zur Git-Root; dann sind die Keys aber bereits
  projektbezogen, und der Store kann genauso gut gleich ins Projekt.

### Empfehlung

`<git-root>/.cascade/markers.json`, Key = **repo-relativer Pfad**. Damit reisen
Marker zwangsläufig mit dem Dokument, über *einen* Kanal, plattformunabhängig.
Fallback auf `stdpath("data")`, wenn kein Git-Repo vorhanden ist — dann eben
nur gerätelokal, mit ehrlicher Erwartung.

## Vorgeschlagene Architektur

```
lua/cascade/anchor/
  init.lua      -- öffentliche API: set/unset/toggle/list/clear
  extmark.lua   -- Laufzeit-Layer (Namespace, Sign/virt_text, Buffer-State)
  fingerprint.lua -- Zeile -> Fingerprint, Fingerprint -> Zeile (rein, testbar)
  store.lua     -- Laden/Speichern, Pfad-Auflösung, JSON-Serialisierung
```

Schnitt nach den Repo-Prinzipien: `fingerprint.lua` bleibt **rein**
(String rein, String/Position raus, kein Buffer-Zugriff) und ist damit
trivial testbar — analog zu `lists/marker.lua`. Der Buffer- und IO-Kontakt
konzentriert sich in `extmark.lua` und `store.lua`.

Eigene Domain (`anchor`) statt Unterordner von `lists`, weil das Konzept
„markierte Stelle im Buffer, persistiert" perspektivisch nicht auf Listen
beschränkt ist.

### Datenformat (Entwurf)

```json
{
  "version": 1,
  "files": {
    "docs/notes.md": [
      {
        "kind": "restart",
        "value": 1,
        "line_hint": 42,
        "fingerprint": "sha1:…",
        "context": ["…vorherige Zeile…", "…nächste Zeile…"]
      }
    ]
  }
}
```

`kind` von Anfang an mitführen, auch wenn zunächst nur `restart` unterstützt
wird — ein späteres `join` (Block über eine Lücke hinweg zusammenhalten) ist
das naheliegende Gegenstück und soll kein Formatbruch werden. `version` erlaubt
Migration.

### Lifecycle

| Event | Aktion |
| --- | --- |
| `BufReadPost` | Store laden, Fingerprints auflösen, Extmarks setzen |
| Edit (Laufzeit) | nichts — Neovim verschiebt Extmarks selbst |
| `BufWritePost` | Extmarks → Fingerprints, Store schreiben |
| `BufDelete` | Buffer-State freigeben |

Alles im bestehenden Augroup, alles über `pcall` abgesichert: ein defekter
Store darf **nie** das Editieren blockieren. Bei Parse-Fehler einmal warnen und
ohne Marker weiterarbeiten.

### Integration ins Renumbering

Minimal-invasiv: `renumber` fragt vor dem Blockabschluss ab, ob auf der Zeile
ein `restart`-Anker sitzt, und behandelt ihn wie einen harten Break — analog zu
`marker.is_continuation`. Der Anker gewinnt gegen `blank_break` in beide
Richtungen.

Wichtig: die Kernfunktionen (`renumber.run/tree/all`) müssen ohne Anchor-Daten
weiter funktionieren. Der Anchor-Layer ist ein **optionaler Aufsatz**, kein
neuer Pflichtparameter — sonst ist die Testbarkeit dahin.

### Bedienung

| Command | Wirkung |
| --- | --- |
| `:CascadeAnchor` | Anker auf der aktuellen Zeile setzen/entfernen (Toggle) |
| `:CascadeAnchorClear` | alle Anker im Buffer entfernen |
| `:CascadeAnchorList` | Anker des Buffers auflisten (inkl. verwaister) |

Darstellung als Sign in der Signcolumn oder `virt_text` am Zeilenende;
konfigurierbar, defaultmäßig dezent.

## Risiken

- **Fingerprint-Kollisionen** bei repetitiven Listen (`1. TODO`, `1. TODO`, …).
  Kontextzeilen helfen, lösen es aber nicht vollständig.
- **Selbst-Invalidierung**: Renumbering ändert die Ankerzeile, wenn der
  Marker-Präfix in den Fingerprint einfließt. Deshalb Präfix zwingend
  abtrennen.
- **Merge-Konflikte** in `markers.json` bei Team-Nutzung — für den
  Single-User-Fall irrelevant, aber ein Grund, das Format flach und
  zeilenweise diffbar zu halten.
- **Store-Drift**: Datei wird außerhalb von Neovim bearbeitet (anderer Editor,
  `sed`, Merge) → Anker verwaisen. Unvermeidbar; sauber melden statt raten.

## Abgrenzung: brauchen wir das überhaupt?

Der Gegenentwurf ist ein **In-Dokument-Token**:

```markdown
<!-- cascade: restart -->
```

Das verletzt Anforderung 1, erfüllt 2–4 aber **geschenkt**: kein Store, kein
Fingerprinting, kein Lifecycle, kein Sync-Problem, kein verwaister Zustand.
Aufwand: eine Handvoll Zeilen in `is_continuation`. In Markdown wird es nicht
gerendert.

Der unsichtbare Marker lohnt sich erst, wenn Anker **häufig** gesetzt werden
und die Dokumente strikt sauber bleiben müssen. Bei drei Ankern im Jahr steht
ein komplettes neues Subsystem gegen einen HTML-Kommentar.

Hinzu kommt: seit `lists.renumber.blank_break = 0` (Default) ist die Leerzeile
selbst wieder ein natürlicher, tippbarer „ab hier neu"-Marker — den jeder
Markdown-Renderer versteht. Der explizite Anker bleibt damit nur noch für den
Fall „zwei Listen direkt untereinander ohne Leerzeile" nötig.

## Nächster Schritt

Nicht mit dem Store beginnen, sondern mit **(B)**: `fingerprint.lua` als
isolierten Prototyp bauen und gegen realistische Dokumente testen
(Umformulierungen, verschobene Blöcke, Duplikate). Trägt das Anchoring nicht,
trägt das ganze Feature nicht — und der Store drumherum ist danach reine
Fleißarbeit.

Vorher: den neuen `blank_break`-Default im Alltag beobachten und prüfen, ob
überhaupt ein Restbedarf bleibt.

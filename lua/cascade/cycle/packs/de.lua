---@module 'cascade.cycle.packs.de'
--- German cycle groups. Enabled by default (`cycle.packs`).
---
--- `an`/`aus` is deliberately absent even though it is idiomatic: `aus` is
--- already the off-state of `ein`/`aus`, and a word may only appear in one
--- group of the effective set -- the first group wins and the second becomes
--- unreachable (`:checkhealth cascade` reports such collisions).

return {
  { "wahr", "falsch" },
  { "ja", "nein" },
  { "ein", "aus" },
  { "aktiviert", "deaktiviert" },
  { "aktiv", "inaktiv" },
  { "sichtbar", "unsichtbar" },
  { "anzeigen", "verbergen" },
  { "erlauben", "verbieten" },
  { "offen", "geschlossen" },
  { "gesperrt", "entsperrt" },
  { "verbunden", "getrennt" },
  { "starten", "stoppen" },
  { "oben", "unten" },
  { "links", "rechts" },
  { "vor", "zurück" },
  { "stumm", "laut" },
}

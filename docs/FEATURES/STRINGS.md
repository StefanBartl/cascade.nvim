# strings — advance a literal's kind when its contents ask for it

The other domains advance a token; this one advances the *quotes around* the
cursor. Type `${` inside a JavaScript `"string"` and the string becomes a
`` `template string` ``. Type `{name}` inside a Python `"string"` and it
becomes an `f"string"`. Delete the last placeholder and the literal turns back
into a plain one. Nothing to press: the conversion runs after `InsertLeave`
and `TextChanged`, one tick deferred so other autocmds finish first.

The idea is nvim-puppeteer's, and so are the guards. What cascade adds is the
placement: detect a context, advance it one step, fall back to doing nothing
— the same pattern as `cycle` and `lists`, so the domain has the same shape
(feature switches, filetype lists, a `:Cascade strings` subcommand, a
per-buffer off switch) as its siblings.

## What converts

| Language | From | To | Back when |
| --- | --- | --- | --- |
| JavaScript, TypeScript, JSX/TSX, Vue, Astro, Svelte | `"… ${x} …"` or a quoted string that gained a newline | `` `… ${x} …` `` | the template has no `${}` and no newline left, and is not a tagged template (`` tag`…` ``) |
| Python | `"… {name} …"` | `f"… {name} …"` | the f-string has no `{…}` left (`{}`, `{0}` and `{, }` never count — they are set, dict and `.format` index syntax too often); `t"…"` template strings are left alone |
| Lua (opt-in) | `"%s items"` | `("%s items"):format()`, cursor placed inside the parentheses | the literal inside `(…):format()` has no placeholder left |

The Lua converter is off by default. It is the one that can be wrong in
ordinary code — a `%s` is a placeholder in one literal and a pattern class in
the next — so it stays behind `strings.features.lua_format = true`, and even
then never touches a literal that looks like a pattern (`%s+`, `%d`, `%w`),
or one that is an argument of `match`, `gmatch`, `find`, `gsub` or
`string.format`.

## Guards

- **Empty literal:** `""` is left alone, you are about to type into it.
- **Size:** a literal longer than `strings.max_characters` (200) is left
  alone. A half-typed line can parse as one enormous string, and rewriting
  that would be worse than doing nothing.
- **No parser:** the domain needs a Tree-sitter parser for the buffer's
  language, because "where does this string start and end" is not a line-scan
  question. Without one it is silently inactive; `:checkhealth cascade` says
  so.
- **Buffer kind:** only real file buffers (`buftype = ""`); a scratch or
  terminal buffer never converts.

Every conversion is joined to the previous undo step, so `u` undoes your
edit and the conversion together rather than leaving the quotes half-changed.

## Turning it off for one buffer

`:Cascade strings off` (and `on`, `toggle`) switches the domain for the
current buffer only, via `b:cascade_strings`. `:Cascade strings now` runs
the converter once at the cursor, which is also the way to use the domain
with the autocmds disabled (`strings.on = {}`).

- **Module:** `lua/cascade/strings/init.lua` (`template_string`,
  `python_fstring`, `lua_format`, `convert`, `set_buffer`)
- **Config:** `strings.enable`, `strings.features.{template,fstring,lua_format}`,
  `strings.{template,fstring,lua_format}_filetypes`, `strings.max_characters`,
  `strings.quote`, `strings.on` — see [configuration.md](../configuration.md#strings)
- **Usercmds:** `:Cascade strings on|off|toggle|now`
- **Autocmds:** `cascade_strings` (`FileType`), then buffer-local
  `InsertLeave`/`TextChanged` — see [BINDINGS.md](../BINDINGS.md#autocommands)

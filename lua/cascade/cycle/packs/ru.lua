---@module 'cascade.cycle.packs.ru'
--- Russian cycle groups. Opt-in via `cycle.packs`.
---
--- Cyrillic works because `'iskeyword'`'s `@` class covers every alphabetic
--- character, so cascade's `\k\+` token scan sees these as words like any
--- other. Case is matched literally, though: `case_shape`/`apply_shape` use
--- Lua's ASCII-only `upper`/`lower`, so a capitalised `Да` is not recognised.

return {
  { "истина", "ложь" },
  { "да", "нет" },
  { "включено", "выключено" },
  { "активный", "неактивный" },
  { "видимый", "скрытый" },
  { "показать", "скрыть" },
  { "разрешить", "запретить" },
  { "открыт", "закрыт" },
  { "запуск", "остановка" },
  { "вверх", "вниз" },
  { "влево", "вправо" },
}

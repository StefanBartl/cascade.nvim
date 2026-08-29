---@module 'cascade.cycle.packs.dev'
--- Language-neutral developer cycles: environments, workflow states, levels,
--- release channels, HTTP verbs, size scales. Enabled by default
--- (`cycle.packs`).
---
--- Sizes use the `xs`/`sm`/`md`/`lg`/`xl` scale rather than
--- `small`/`medium`/`large`: the spelled-out form shares `medium` with
--- `low`/`medium`/`high`, and a word may only live in one group of the
--- effective set (the first wins, the second becomes unreachable).

return {
  { "dev", "stage", "prod" },
  { "todo", "doing", "done" },
  { "draft", "review", "final" },
  { "low", "medium", "high" },
  { "alpha", "beta", "rc", "stable" },
  { "debug", "info", "warn", "error" },
  { "get", "post", "put", "patch", "delete" },
  { "xs", "sm", "md", "lg", "xl" },
}

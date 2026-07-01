# Tests

Headless spec suite for cascade.nvim. Pure line-scanning logic (marker parsing,
roman/alpha, renumber, transforms) is trivially testable without a UI.

## Run

From the repo root:

```sh
nvim --headless -u NONE -c "set rtp+=." -c "luafile docs/TESTS/run.lua" -c "qa!"
```

or via the backwards-compatible entry point:

```sh
nvim --headless -u NONE -c "set rtp+=." -c "luafile scripts/smoke.lua" -c "qa!"
```

The runner prints one line per spec and exits non-zero on the first failure
(`CASCADE_TESTS_OK` / `CASCADE_SMOKE_OK` on success).

## Layout

| File                | Covers                                                              |
| ------------------- | ------------------------------------------------------------------- |
| `harness.lua`       | Shared assertions (`eq`, `ok`) and a `scratch(ft)` buffer helper.   |
| `units_spec.lua`    | Pure functions: roman, alpha, marker parse/advance/render.          |
| `lists_spec.lua`    | Checkbox, renumber (run/tree/all), transforms, indent, move.        |
| `cycle_spec.lua`    | Word / boolean cycle.                                               |
| `commands_spec.lua` | `:Cascade*` commands exist; feature toggles gate actions.           |
| `run.lua`           | Runner: loads every `*_spec.lua`, reports results, sets exit code.  |

## Adding a spec

Create `<name>_spec.lua` returning `function(H) … end` (use `H.eq` / `H.ok` /
`H.scratch`) and add its filename to the `specs` list in `run.lua`.

# Filetree feature audit — cascade.nvim

> Part of the cross-repo effort to collect filetree-manager features (Neotree,
> NvimTree, Netrw, …) into a future `filetree.nvim` that docks them onto whatever
> manager the user runs. This file records the audit **for cascade.nvim only**.

## Result: none

cascade.nvim is a **lists & word-cycling** plugin. It has **no filetree
integration of any kind** — verified by a full search of `lua/`, `plugin/` and
`doc/`:

```
grep -riE "neotree|nvim-tree|nvimtree|netrw|filetree" lua/ plugin/ doc/
→ (no matches)
```

| Feature | Origin (file, line) | Theme | Notes |
| --- | --- | --- | --- |
| — | — | — | cascade contributes nothing to `filetree.nvim` |

### Why there is nothing to extract

cascade operates purely on the **text of the current buffer** (list markers, the
word under the cursor). It never inspects, renders or acts on a directory tree,
a file explorer buffer, or filesystem entries. There is therefore no feature to
generalise cross-manager and no code to migrate into `filetree.nvim`.

**Action for cascade.nvim: none.** This audit is complete and closed.

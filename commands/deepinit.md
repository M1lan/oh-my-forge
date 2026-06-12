---
name: deepinit
description: Generate or regenerate hierarchical AGENTS.md documentation across the codebase. Explores the directory tree and writes root and per-subdirectory AGENTS.md files. Idempotent — preserves manually annotated sections.
---

Generate AGENTS.md documentation for: {{parameters}}

Load the `deepinit` skill and follow its workflow exactly.

If {{parameters}} is empty, run deepinit on the current working directory.

If {{parameters}} names a specific directory or flag (e.g. `--root-only`, `src/`), scope the generation accordingly.

Follow the deepinit skill's execution workflow:

1. Map the directory tree (delegate to sage).
2. Classify scope (small vs large codebase).
3. Generate AGENTS.md files level by level, parent before child.
4. Preserve `<!-- MANUAL: -->` sections in any pre-existing files.
5. Validate parent references after generation.

Report which files were created or updated, and any directories that were skipped (empty, generated-only, etc.).

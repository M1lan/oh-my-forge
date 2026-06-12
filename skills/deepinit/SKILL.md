---
name: deepinit
description: Generate or regenerate hierarchical AGENTS.md documentation across the entire codebase. Explores the directory tree, writes a root AGENTS.md (project overview, architecture, conventions, commands) and per-major-subdirectory AGENTS.md files for large codebases. Idempotent — preserves sections marked with a MANUAL comment on regeneration. Use when the user asks to "deepinit", "initialize the codebase docs", "generate AGENTS.md", "document the project for agents", or when starting work on an unfamiliar codebase.
---

# Deep Init

Generate hierarchical AGENTS.md documentation that makes every directory in the codebase navigable by AI agents.

## Core concept

AGENTS.md files are AI-readable documentation. Root `./AGENTS.md` and `~/forge/AGENTS.md` are the two files forge auto-loads every session. Subdirectory AGENTS.md files are NOT auto-loaded — they serve as on-demand context that agents read when exploring those directories.

The goal is a hierarchy where any agent dropped into any directory can quickly understand:

- What the directory is for.
- Which files matter and what they do.
- How to work here safely (conventions, test commands, patterns).
- Which other parts of the codebase this depends on.

## Hierarchy structure

```text
./AGENTS.md                          ← root, auto-loaded by forge
├── src/AGENTS.md                    ← on-demand; agent reads when entering src/
│   ├── src/components/AGENTS.md     ← on-demand
│   └── src/utils/AGENTS.md          ← on-demand
└── docs/AGENTS.md                   ← on-demand
```

Every subdirectory AGENTS.md includes a parent reference:

```markdown
<!-- Parent: ../AGENTS.md -->
```

Root AGENTS.md has no parent tag.

## AGENTS.md template

```markdown
<!-- Parent: {relative_path}/AGENTS.md -->
<!-- Generated: YYYY-MM-DD | Updated: YYYY-MM-DD -->

# {Directory Name}

## Purpose

{One-paragraph description of what this directory contains and its role in the project.}

## Key Files

| File | Description |
|---|---|
| `file.ext` | Brief description of purpose |

## Subdirectories

| Directory | Purpose |
|---|---|
| `subdir/` | What it contains (see `subdir/AGENTS.md`) |

## Working Here

{Special instructions for agents modifying files in this directory — naming conventions,
patterns to follow, patterns to avoid.}

## Testing

{How to run tests that cover this directory. Prefer commands over prose.}

## Dependencies

**Internal:** {references to other parts of this codebase this depends on}

**External:** {key packages / libraries used here}

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
```

## Execution workflow

### Step 1 — Map the directory tree

Delegate to sage via the `task` tool:

```text
task(sage): List all directories recursively. Exclude: node_modules, .git, dist, build,
__pycache__, .venv, coverage, .next, .nuxt, target, out, .cache, vendor.
Return a flat list sorted by depth.
```

### Step 2 — Classify scope

**Small codebase** (< 20 directories): generate AGENTS.md for root + every non-trivial directory.

**Large codebase** (≥ 20 directories): generate AGENTS.md for root + every first-level subdirectory + any second-level directory that contains more than 5 files or has its own subdirectories. Skip deeper levels unless they are independently significant.

### Step 3 — Generate level by level

Process parent levels before child levels so parent references are valid when children are written.

For each directory:

1. Read all files in the directory (delegate batch reads to sage when there are many).
2. Identify the directory's role from file names, imports, and README content.
3. Write AGENTS.md using the template above.

### Step 4 — Regeneration (idempotent mode)

When an AGENTS.md already exists at a path:

1. Read the existing file.
2. Find the `<!-- MANUAL: -->` comment.
3. Preserve everything below that comment verbatim.
4. Regenerate the auto-generated sections above it.
5. Update the `Updated: YYYY-MM-DD` timestamp.

### Step 5 — Validate

After generation, verify:

- Every non-root AGENTS.md has a `<!-- Parent: -->` tag pointing to a file that exists.
- No orphaned AGENTS.md files remain for directories that no longer exist.
- Root AGENTS.md has no parent tag.

Use `fs_search` with pattern `**/AGENTS.md` to enumerate all generated files, then check parent references with `read`.

## Agent delegation

| Task | Delegate to |
|---|---|
| Directory mapping | sage (read-only, efficient) |
| File content analysis | sage (batch reads) |
| Writing AGENTS.md files | forge (write tool) |
| Architecture review of root AGENTS.md | architect (optional, for complex codebases) |

## Root AGENTS.md content guide

The root AGENTS.md is the most important file — it is auto-loaded every session. It should cover:

1. **Project purpose** — one paragraph, what the project does and why it exists.
2. **Architecture overview** — the top-level structure and how major parts relate.
3. **Key entry points** — main executable, primary config files, package manifest.
4. **Conventions** — naming, code style, test requirements, branch/commit rules.
5. **Commands** — how to build, test, lint, run the project. Use actual commands, not prose.
6. **Subdirectory map** — table of first-level directories with one-line purposes.
7. **Working agreements** — what agents must do before declaring work done (lint, tests, etc.).

Do NOT embed static file inventories or dependency tables in root AGENTS.md — they go stale. Point at `package.json`, `Cargo.toml`, or the equivalent instead.

## Empty directory handling

| Condition | Action |
|---|---|
| No files, no subdirectories | Skip — do not create AGENTS.md |
| No files, has subdirectories | Minimal AGENTS.md with subdirectory listing only |
| Only generated artifacts (`*.min.js`, `*.map`, `*.pyc`) | Skip |
| Only config files | Create AGENTS.md describing the configuration purpose |

## Parallelization

Same-level directories can be processed in parallel. Assign multiple directories to sage for reading in a single task call when they share similar structure. Write operations execute after reads complete.

## Quality checklist

Before completing:

- [ ] Root AGENTS.md covers project purpose, architecture, commands, and conventions.
- [ ] Every subdirectory AGENTS.md has a correct `<!-- Parent: -->` tag.
- [ ] MANUAL sections from any pre-existing AGENTS.md files are preserved.
- [ ] No generic boilerplate — every description reflects actual file content.
- [ ] No static snapshots that will go stale — commands over inventories.
- [ ] Regeneration is idempotent: running deepinit again would produce only timestamp differences.

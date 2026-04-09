# `plans/` Directory

This directory holds plan files produced by the `plan` and `ralplan` skills. Each plan file is a concrete, executable roadmap consumed by forge's built-in `execute-plan` skill.

---

## Naming convention

```
plans/YYYY-MM-DD-<slug>-v<N>.md
```

- `YYYY-MM-DD` -- date the plan was drafted (ISO 8601).
- `<slug>` -- kebab-case short name summarizing the scope.
- `v<N>` -- integer version, incremented on each revision.

Examples:

```
plans/2026-04-09-add-refresh-token-flow-v1.md
plans/2026-04-09-add-refresh-token-flow-v2.md
plans/2026-03-20-migrate-database-v1.md
```

---

## Plan file structure

Every plan file MUST have:

1. **Frontmatter** (optional but recommended):
   ```yaml
   ---
   title: Add refresh token flow
   status: draft | active | done | abandoned
   owner: <name>
   ---
   ```
2. **Ground Truth** section -- canonical facts the plan relies on. If anything here is contradicted during execution, STOP and ask.
3. **Objectives** -- what we are building and why.
4. **Context** -- current state, relevant files, dependencies.
5. **Risk Assessment** -- what could go wrong.
6. **Implementation Phases** -- the meat. Each task uses a task marker.
7. **Verification** -- how we prove the plan worked.
8. **Rollback Plan** -- how to undo.

---

## Task markers

Forge's `execute-plan` skill reads these markers:

| Marker | Meaning |
|---|---|
| `[ ]` | Not started |
| `[~]` | In progress |
| `[x]` | Complete |
| `[!]` | Blocked / needs attention |

Example:

```markdown
- [x] A1. Delete `forge.yaml`.
- [x] A2. Create `.forge.toml` with verified schema.
- [~] A3. Write `.mcp.json.example`.
- [ ] A4. Create `AGENTS.md` at repo root.
- [!] A5. Fix all agent tools frontmatter -- BLOCKED waiting on schema validation.
```

---

## Lifecycle

1. **Draft** -- plan skill writes `v1`. Status: `draft`.
2. **Review** -- critic skill runs a consensus pass. If changes needed, plan skill writes `v2`. Repeat.
3. **Approved** -- plan status flips to `active`. Execute-plan can now consume it.
4. **Execute** -- user runs `execute-plan plans/YYYY-MM-DD-<slug>-v<N>.md`. Markers flip as tasks progress.
5. **Complete** -- all markers are `[x]`. Status: `done`.
6. **Archive** -- keep the file in `plans/` for recall. Do not delete -- historical plans are valuable.

---

## Versioning

Create a new `v<N+1>` file when:

- A critic pass requests substantive changes.
- The user adds new requirements mid-plan.
- An assumption in Ground Truth is contradicted and the plan must be re-scoped.

Do **not** create a new version for:

- Fixing typos (edit in place).
- Flipping task markers (edit in place).
- Adding notes to completed tasks (edit in place).

---

## Recall

Past plans are valuable context for future sessions. The `recall` skill searches `plans/` first when answering "have we done this before?" or "what did we decide about X?".

If a plan was abandoned, mark it `status: abandoned` in the frontmatter rather than deleting -- future sessions can learn from what did not work.

---

## Related

- [`../skills/plan/SKILL.md`](../skills/plan/SKILL.md) -- the plan skill.
- [`../skills/ralplan/SKILL.md`](../skills/ralplan/SKILL.md) -- the consensus-planning skill.
- [`../skills/recall/SKILL.md`](../skills/recall/SKILL.md) -- search past plans.
- `execute-plan` -- forge built-in skill that consumes plan files.

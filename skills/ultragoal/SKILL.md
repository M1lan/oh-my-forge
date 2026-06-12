---
name: ultragoal
description: Durable multi-goal workflow that persists a goal ledger as a plan file at plans/YYYY-MM-DD-ultragoal-<slug>-v1.md. Breaks a brief into ordered goals, each as a plan section with forgecode task markers. Resumes across sessions — on invocation always checks for an active ultragoal plan first. Status checkpoints written back into the plan file after each goal. Use when the user says "ultragoal", wants a durable multi-step initiative tracked across sessions, or needs sequential ordered goals with completion gating.
---

# Ultragoal

A durable multi-goal workflow. A brief becomes an ordered list of goals. Each goal lives as a section in a plan file, with forgecode `[ ]/[~]/[x]/[!]` task markers so the built-in `execute-plan` skill can drive execution. The plan file is the single source of truth — progress survives session restarts.

## Core concept

Ultragoal solves the cross-session persistence problem. A complex initiative spanning many work sessions needs a stable artifact that any future session can read and resume. This skill creates and maintains that artifact as a standard plan file.

It is not a planning-only tool — it drives execution and checkpoints progress. It is not a single-task tool — use `ralph` for that. It is the durable multi-goal layer.

## On invocation: always resume before creating

**Before creating a new ultragoal plan, search for an existing active one:**

```text
fs_search pattern: "plans/*-ultragoal-*-v*.md"
```

Read any matching files and check their frontmatter `status` field. If an active plan exists (`status: active`), resume it — do not create a new one unless the user explicitly wants a fresh plan or a different brief.

If the user wants a new plan alongside an existing one, use a distinct slug to avoid collision.

## Plan file structure

Save to `plans/YYYY-MM-DD-ultragoal-<slug>-v1.md`. The slug is a 2-4 word kebab-case summary of the brief.

```markdown
---
title: <initiative title>
status: active
owner: <user or agent>
brief: <one-sentence summary of the original brief>
created: YYYY-MM-DD
updated: YYYY-MM-DD
---

## <Initiative Title> — Ultragoal

## Brief

<The original brief, verbatim or lightly edited for clarity.>

## Goals

<Numbered list of goals with one-line purpose each — the navigation index.>

1. **G001** — <goal title>: <one-line purpose>
2. **G002** — <goal title>: <one-line purpose>
...

## Checkpoint Log

<Append a line here after each goal completes or fails. Do not delete lines.>

- YYYY-MM-DD — G001 complete: <one-line evidence summary>
- YYYY-MM-DD — G002 failed: <blocker description>

---

## G001 — <Goal Title>

**Objective:** <What does "done" look like for this goal?>

**Acceptance criteria:**

- <Concrete, testable criterion>
- <Concrete, testable criterion>

**Tasks:**

- [ ] G001-T1. <Task>. Acceptance: <how we know it's done>.
- [ ] G001-T2. <Task>. Acceptance: <how we know it's done>.

**Status:** PENDING

---

## G002 — <Goal Title>

...same structure...
```

## Task markers (forgecode plan format)

| Marker | Meaning |
|---|---|
| `[ ]` | Not started |
| `[~]` | In progress |
| `[x]` | Complete |
| `[!]` | Blocked — append reason on the same line |

The built-in `execute-plan` skill reads these markers and updates them in-place.

## Workflow

### Creating a new ultragoal

1. Read the brief (from user prompt or a file the user points at).
2. Decompose the brief into 2-7 ordered goals. Fewer is better — goals should be independently completable chunks, not micro-tasks.
3. For each goal, write the objective and 2-4 acceptance criteria before writing tasks.
4. Write the plan file to `plans/YYYY-MM-DD-ultragoal-<slug>-v1.md`.
5. Confirm the plan with the user before starting execution.

### Executing goals

Execute goals in order (G001, G002, ...). Do not start G002 until G001 is checkpointed.

For each goal:

1. Update the goal's `**Status:**` line to `IN PROGRESS` and flip relevant tasks to `[~]`.
2. Update the plan file's `updated:` frontmatter date.
3. Execute the tasks. Use `execute-plan` for task-marker-driven execution, or work directly for simple goals.
4. Run verification: run tests, check build, confirm acceptance criteria.
5. Checkpoint the goal (see below).
6. Move to the next goal.

### Checkpointing

After each goal, write a checkpoint entry to the `## Checkpoint Log` section and update the goal's `**Status:**` line:

```markdown
- YYYY-MM-DD — G001 complete: tests pass (42/42), acceptance criteria met
```

For a failed or blocked goal:

```markdown
- YYYY-MM-DD — G001 blocked: dependency X not available — waiting on external team
```

Flip the goal's tasks to `[x]` (complete) or `[!]` (blocked). Update `updated:` in frontmatter.

### Final completion

When all goals reach `[x]`:

1. Run the verify skill over the full initiative.
2. Flip the plan frontmatter `status: done`.
3. Append a final checkpoint entry summarizing the initiative.

If the final `verify` pass is not clean, create an additional goal `G00N — Resolve final blockers` and continue.

### Resuming in a new session

On any invocation where an active plan exists:

1. Read the plan file.
2. Find the first goal with `**Status:** PENDING` or `IN PROGRESS`.
3. Report current state to the user: which goals are done, which is next, what the acceptance criteria are.
4. Ask the user to confirm before resuming, unless they already said "resume" or "continue".

## Quality standards

- Each goal must have concrete, testable acceptance criteria — not "improve X" but "X achieves Y under condition Z".
- Do not check off a goal without evidence (test output, build exit code, file inspection).
- The checkpoint log is append-only — never delete or edit existing entries.
- If a goal must be revised after creation, note the revision in the checkpoint log rather than silently editing the goal section.

## When to use related skills

| Need | Use |
|---|---|
| Single-task persistence loop | `ralph` |
| Planning-only artifact (no execution) | `plan` |
| Multi-perspective plan deliberation | `ralplan` |
| Parallel agent execution within a goal | `team` |
| Final verification gate | `verify` |

---
name: ralplan
description: Consensus planning loop -- planner drafts, architect reviews, critic evaluates, iterate until approval, then emit a plans/YYYY-MM-DD-slug-vN.md file ready for execute-plan. Use when the request is risky, ambiguous, high-impact, or "vague plus a verb" (e.g. "ralph improve performance"). Blocks execution modes until a concrete, verifiable plan exists.
---

# Ralplan (Consensus Planning)

Forge-native consensus planning. Takes a fuzzy request and produces a concrete, testable plan that three roles agree on.

## When to invoke

- Request is vague but execution-flavored ("make it faster", "add auth", "improve the UI").
- A change touches auth, migrations, destructive operations, production, or compliance/PII.
- The user explicitly says "ralplan" or "consensus plan".
- An execution skill (autopilot, ralph, team, turbo) is about to run on an underspecified request and the **pre-execution gate** fires (see below).
- Request has <=15 effective words and no concrete anchors (file path, function name, issue number, error reference).

## Pre-execution gate (auto-trigger)

Gate FIRES (route through ralplan first) when all of:

- User requested an execution mode (autopilot/ralph/team/turbo/ultrawork).
- Request has no concrete anchor (no `path/to/file`, no `functionName`, no `#42`, no error text, no code block, no numbered steps).

Gate PASSES (execute directly) when ANY of:

- File path present
- Function / class / symbol name present
- Issue / PR number present (`#42`)
- Error reference ("TypeError: ...")
- Numbered acceptance criteria
- Code block with the intended change
- Escape prefix: `force:` or `!` at start of request

## Workflow

1. **Planner pass.** Draft the plan: goal, approach, files touched, test strategy, acceptance criteria, risks, rollback. Produce a RALPLAN-DR summary: Principles (3-5), Decision Drivers (top 3), Viable Options (>=2 or justified single).
2. **Architect review.** Evaluate architectural soundness. MUST provide a steelman of at least one alternative approach and name the real tradeoff tension. Flag principle violations.
3. **Critic review.** Evaluate against: principle-option consistency, fair alternatives, risk-mitigation clarity, testable acceptance criteria, concrete verification steps. Deliver verdict (APPROVE / ITERATE / REJECT).
4. **Re-review loop.** If not APPROVE, collect feedback -> revise with planner -> back to architect -> back to critic. Max 5 iterations.
5. **Emit plan file.** On APPROVE, write `plans/YYYY-MM-DD-<slug>-v<N>.md` using the plan skill's task-marker format (`[ ] [~] [x] [!]`) so execute-plan can consume it directly.

> Architect and critic passes MUST run sequentially, not in parallel. Architect first, then critic reads architect's notes.

## Plan file requirements

A ralplan output MUST include all of the plan skill's required sections (Ground Truth, Objectives, Context, Risk Assessment, Implementation Phases with `[ ]` markers, Verification, Rollback Plan) plus:

- **ADR section**: Decision / Drivers / Alternatives Considered / Why Chosen / Consequences / Follow-ups
- **RALPLAN-DR summary**: Principles / Decision Drivers / Viable Options

## Rules

- NEVER implement directly after a ralplan run. Emit the plan and stop. The user (or the next skill -- team, autopilot, ralph) executes it.
- NEVER skip architect or critic to save time.
- If after 5 iterations critic still rejects, present the best version and stop -- do not force approval.
- Cite all file references as `path:line`.

## Output

```text
## Ralplan Result: APPROVED (after N iterations)

### Plan file
plans/2026-04-09-<slug>-v1.md

### RALPLAN-DR Summary
- Principles: ...
- Decision Drivers: ...
- Viable Options: ...

### ADR
- Decision: ...
- Why: ...
- Alternatives considered: ...
- Consequences: ...

### Next step
Run `execute-plan plans/2026-04-09-<slug>-v1.md` or invoke the team/autopilot/ralph skill to implement.
```

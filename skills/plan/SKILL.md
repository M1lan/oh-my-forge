---
name: plan
description: Strategic planning workflow that produces a comprehensive, actionable plan file at plans/YYYY-MM-DD-<slug>-v<N>.md before any code is written. Supports interview mode (adaptive requirements gathering), direct mode (skip interview), and review mode (evaluate an existing plan). Uses the forgecode plan task-marker format ([ ]/[~]/[x]/[!]) so output is consumable by execute-plan. Use when the user asks to plan, design, or scope a piece of work before implementation.
---

# Plan — Strategic Planning Workflow

<Purpose>
Produce a comprehensive, actionable work plan saved to `plans/YYYY-MM-DD-<slug>-v<N>.md` in the forgecode plan format. Plans are the contract between requirements and execution — a good plan makes execution mechanical, a bad plan guarantees rework.
</Purpose>

<Use_When>

- User asks to "plan", "strategize", "design", "scope", or "think through" a piece of work
- Request is broad or vague ("add real-time collaboration", "improve performance") and needs shaping before code
- Task touches 3+ files, 2+ modules, or introduces a new dependency/pattern
- User says "let's plan this first" or asks for a written plan
- Existing plan needs review — invoke with `--review plans/<file>.md`
- Task is risky: auth, data migration, destructive changes, public API breakage, compliance/PII
</Use_When>

<Do_Not_Use_When>

- User asks a single focused question that can be answered directly
- Task is a trivial fix (one-line change, typo, renaming a variable)
- User already said "just do it" or "skip the plan"
- User wants autonomous end-to-end execution — use `autopilot` or `ralph` instead
- You already have a plan and the user wants it executed — use the `execute-plan` built-in skill
</Do_Not_Use_When>

<Why_This_Exists>
Jumping into code without understanding requirements leads to rework, scope creep, missed edge cases, and architectural debt. A structured plan forces requirements gathering, grounds claims in the actual codebase, and makes downstream execution mechanical. The forgecode plan format with `[ ]/[~]/[x]/[!]` markers is directly executable by the built-in `execute-plan` skill, so a good plan + execute-plan is often the full workflow.
</Why_This_Exists>

<Modes>

| Mode | Trigger | Behavior |
|---|---|---|
| Interview | Default for broad requests | Adaptive question-gathering, one question at a time |
| Direct | `--direct`, or request already has concrete scope | Skip interview, generate plan immediately |
| Review | `--review <path>` | Read existing plan, evaluate against quality criteria, return verdict |
| Consensus | `--consensus` (heavyweight) | Delegate to `ralplan` skill instead (planner + architect + critic deliberation loop) |

</Modes>

<Steps>

## Interview Mode (default)

1. **Classify the request.** Broad (vague verbs, no specific files, touches 3+ areas, no acceptance criteria stated) → interview. Detailed (specific files/modules named, concrete acceptance criteria) → direct mode.

2. **Gather codebase facts FIRST.** Before asking the user "how is X implemented?", delegate to the `sage` sub-agent via the {{tool_names.task}} tool with a focused question like "Find all code related to <concept>, list file paths and entry points." Then ask informed follow-up questions based on what sage finds. Do not ask the user about things you can discover from code.

3. **Ask ONE question at a time.** Never batch. Each question builds on the previous answer. Questions should target:
   - Scope boundaries (what's in, what's out)
   - Acceptance criteria (how will we know it works?)
   - Constraints (timeline, traffic, team, compliance)
   - Risk tolerance (what's the blast radius if this breaks?)

4. **Consult the `analyst` agent** (if available) via {{tool_names.task}} for hidden requirements, edge cases, and risks the user didn't state. Only after the user has clarified the big picture.

5. **Create the plan** when the user signals readiness ("make the plan", "write it up", "I'm ready") OR when you have enough information (scope clear, 2-3 acceptance criteria, main risks identified).

### Direct Mode (`--direct`)

1. **Brief analyst consultation** (optional) — delegate to `analyst` agent for requirements analysis if the scope is non-trivial.
2. **Write the plan directly** using the output format below.
3. **Offer review** — suggest the user run `--review <plan-path>` before execution.

### Review Mode (`--review <path>`)

1. {{tool_names.read}} the plan file.
2. Delegate evaluation to the `critic` agent via {{tool_names.task}} (if shipped), otherwise evaluate against the Quality Criteria below yourself.
3. Return a verdict:
   - **APPROVED** — ready to execute
   - **REVISE** — specific feedback on what to improve, plan stays valid
   - **REJECT** — fundamental issues, re-plan from scratch

</Steps>

<Plan_Output_Format>

Save to `plans/YYYY-MM-DD-<slug>-v<N>.md` (create the `plans/` directory if missing). Use this structure:

```markdown
# <Plan Title> — v<N>

## Objective

<1-2 paragraphs: what problem are we solving, why now, what does success look like>

## Revision history

- **v<N> (YYYY-MM-DD)**: <what changed since last version, or "initial plan">

## Scope

**In scope:**

- <bullet>

**Out of scope (explicit non-goals):**

- <bullet>

## Ground Truth

<Facts verified against the codebase. Every non-trivial claim cites a file:line. If you haven't verified it, don't claim it.>

## Implementation Plan

### Phase A — <Name>

- [ ] A1. <Task>. Acceptance: <how we know it's done>. Files touched: `path/to/file.ext:line-range`.
- [ ] A2. <Task>. ...

### Phase B — <Name>

- [ ] B1. <Task>. ...

## Verification Criteria

- ✅ <Testable criterion>
- ✅ <Testable criterion>

## Potential Risks and Mitigations

1. **<Risk>.** <Description>. **Mitigation:** <action>.
2. ...

## Alternative Approaches

1. **<Alternative>**. Trade-off: <what you give up, what you gain>. Rejected because: <reason>.

## Execution Notes

- <How to execute this plan — which skill/agent to invoke, dependencies between phases, etc.>
```

**Task markers (forgecode plan format):**

- `[ ]` PENDING
- `[~]` IN_PROGRESS
- `[x]` DONE
- `[!]` FAILED (with a one-line reason appended)

The built-in `execute-plan` skill reads these markers and updates them in-place during execution.

</Plan_Output_Format>

<Quality_Criteria>

| Criterion | Standard |
|---|---|
| Clarity | 80%+ of factual claims cite file:line |
| Testability | 90%+ of acceptance criteria are concrete and verifiable |
| Verification | All file references point to files that actually exist |
| Specificity | No vague terms — "fast" becomes "p99 < 200ms", "secure" becomes "passes OWASP ASVS L2" |
| Atomicity | Each task is independently completable (ideally committable) |
| Ground Truth | Every non-obvious claim is cited against source code |

</Quality_Criteria>

<Tool_Usage>

- {{tool_names.task}}: delegate codebase exploration to `sage`, requirements analysis to `analyst`, plan review to `critic`
- {{tool_names.read}}: read files you need to cite in Ground Truth
- {{tool_names.fs_search}} / {{tool_names.sem_search}}: direct investigation when delegation overhead isn't worth it
- {{tool_names.write}}: write the final plan to `plans/YYYY-MM-DD-<slug>-v<N>.md`
- {{tool_names.todo_write}}: track interview progress when there are many open questions
- {{tool_names.followup}}: use structured follow-up questions for scope, priority, and constraint preferences

**CRITICAL:** Gather codebase facts BEFORE asking the user. Never ask "where is X in your codebase?" — delegate to `sage`, then ask informed follow-ups.
</Tool_Usage>

<Examples>

<Good>
Adaptive interview (gathers facts first):

```text
User: Add real-time collaboration to the editor.
Agent: [delegates to sage via task: "Find the editor implementation and any existing realtime/websocket infrastructure"]
Sage: "Editor is at src/editor/Editor.tsx using slate.js. No websocket infrastructure exists.
       There is a REST API at src/api/ using Express."
Agent: "I see your editor uses slate.js and you have a REST API but no realtime infrastructure yet.
       For realtime collaboration, the big decision is CRDT vs OT. CRDT (Yjs, Automerge) is easier
       to scale but has larger payloads. OT (ShareDB) is more mature but harder to operate. Which
       direction matches your scale — 2-5 concurrent editors per doc, or 50+?"
```

Why good: Delegated investigation, then asked an informed question about a real trade-off.
</Good>

<Bad>
Asking about things you could look up:

```text
Agent: "Where is authentication implemented in your codebase?"
User: "Uh, somewhere in src/auth I think?"
```

Why bad: Delegate to `sage` — never make the user read their own code.
</Bad>

<Bad>
Batching:

```text
Agent: "What's the scope, the timeline, the team size, and the risk tolerance?"
```

Why bad: Four questions = four shallow answers. Ask one at a time.
</Bad>

</Examples>

<Failure_Modes_To_Avoid>

- Over-interviewing. Stop as soon as you have enough to plan.
- Asking the user about facts you can discover from code.
- Writing a plan with vague acceptance criteria ("improve performance" instead of "p99 API latency under 200ms at 1000 rps").
- Citing files you haven't actually read.
- Skipping the verification criteria section.
- Producing a plan so long nobody will read it. Aim for signal density over length.
- Forgetting to use the forgecode `[ ]/[~]/[x]/[!]` task markers — the output must be directly executable by `execute-plan`.
</Failure_Modes_To_Avoid>

<Final_Checklist>

- [ ] Plan file saved to `plans/YYYY-MM-DD-<slug>-v<N>.md`
- [ ] Uses forgecode `[ ]` task markers (NOT checkbox-only, NOT `- [ ] TODO:` variants)
- [ ] Objective section: 1-2 paragraphs, concrete
- [ ] Scope section: explicit in-scope AND out-of-scope bullets
- [ ] Ground Truth section: every non-trivial claim cites file:line
- [ ] Verification Criteria: testable, 90%+ concrete
- [ ] Risks + Mitigations: at least the top 3
- [ ] Alternatives Considered: at least one "we rejected this because..." item
- [ ] Execution Notes: tells the reader how to run the plan (which skill/agent)
- [ ] No vague terms without metrics
- [ ] Plan is short enough that a human will actually read it
</Final_Checklist>

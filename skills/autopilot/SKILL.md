---
name: autopilot
description: Full autonomous execution from idea to working code
argument-hint: "<product idea or task description>"
level: 4
---

<Purpose>
Autopilot takes a brief product idea and autonomously handles the full lifecycle: requirements analysis, technical design, planning, parallel implementation, QA cycling, and multi-perspective validation. It produces working, verified code from a 2-3 line description.
</Purpose>

<Use_When>
- User wants end-to-end autonomous execution from an idea to working code
- User says "autopilot", "build me", "create me", "make me", "handle it all", "I want a..."
- Task requires multiple phases: planning, coding, testing, and validation
- User wants hands-off execution
</Use_When>

<Do_Not_Use_When>
- User wants to explore options or brainstorm — use `plan` skill instead
- Task is a quick fix or small bug — use direct executor delegation
- User wants to review or critique an existing plan
</Do_Not_Use_When>

<Execution_Policy>
- Each phase must complete before the next begins
- **CONFIRMATION REQUIRED**: After Phase 0 (Clarification) and Phase 1 (Spec)
- Parallel execution is used within phases where possible
- QA cycles repeat until tests pass (max 5 cycles)
- Cancel with stopping the session at any time
- **NEVER skip directly to execution - always confirm the spec first**
</Execution_Policy>

<Steps>
1. **Phase 0 - Clarification**: Understand the requirements
   - **ALWAYS ask these questions - do NOT skip even if input seems clear**
   - ❯ What tech stack? (React, Vue, Svelte, plain HTML, Next.js, Nuxt, etc.)
   - ❯ What design system? (shadcn/ui, Tailwind + Radix, custom CSS, or none)
   - ❯ Any design reference? (URL, screenshot, or "surprise me")
   - ❯ Project type? (new project, add to existing, or empty dir)
   - Wait for each answer before asking the next question
   - **CONFIRMATION REQUIRED before proceeding**

2. **Phase 1 - Spec**: Create a detailed SPEC.md
   - Product name and vision
   - Design decisions (colors, typography, animations)
   - Component inventory
   - Technical approach
   - **Output SPEC.md and ask for confirmation before proceeding**

3. **Phase 2 - Planning**: Create implementation plan
   - Break down into atomic, testable tasks
   - Identify dependencies between tasks
   - Assign complexity (simple/medium/complex) to each task
   - **Show the plan and wait for "go" or modifications**

4. **Phase 3 - Execution**: Implement the plan
   - Run independent tasks in parallel where possible
   - Use @architect for technical decisions
   - Use @ui-engineer for frontend components
   - Use @designer for design system integration

5. **Phase 4 - QA**: Cycle until all tests pass
   - Run build, lint, test
   - Fix failures iteratively
   - Stop if the same error persists 3 times (fundamental issue)

6. **Phase 5 - Validation**: Multi-perspective review
   - @code-reviewer: Quality review
   - @security-reviewer: Vulnerability check
   - @test-writer: Coverage check

7. **Phase 6 - Cleanup**: Verify everything works
   - Run final test suite
   - Summarize what was built
</Steps>

<Tool_Usage>
- Use @architect for Phase 0-1 architecture decisions
- Use @executor for Phase 2 implementation
- Use @code-reviewer for Phase 4 quality review
- Use @security-reviewer for Phase 4 security validation
</Tool_Usage>

<Examples>
<Good>
User: "autopilot A REST API for a bookstore inventory with CRUD operations using TypeScript"
Why good: Specific domain (bookstore), clear features (CRUD), technology constraint (TypeScript)
</Good>

<Good>
User: "build me a CLI tool that tracks daily habits with streak counting"
Why good: Clear product concept with a specific feature
</Good>

<Bad>
User: "fix the bug in the login page"
Why bad: This is a single focused fix, not a multi-phase project
</Bad>
</Examples>

<Final_Checklist>
- [ ] All 5 phases completed
- [ ] Tests pass (verified)
- [ ] Build succeeds (verified)
- [ ] User informed of completion
</Final_Checklist>

---
name: deep-interview
description: Socratic requirements clarification before any code is written
argument-hint: "<vague idea or concept>"
level: 4
---

<Purpose>
Deep Interview uses Socratic questioning to clarify requirements before any code is written. It exposes hidden assumptions and ensures the user knows exactly what they're asking for. This prevents the common pattern of building the wrong thing correctly.
</Purpose>

<Use_When>
- User has a vague idea or open-ended request
- User says "deep-interview", "clarify", "not sure what I want"
- Requirements are unclear or ambiguous
- Complex feature with many edge cases
</Use_When>

<Do_Not_Use_When>
- Requirements are already clear and specific
- User explicitly says "just build it"
- Quick task with no ambiguity
</Do_Not_Use_When>

<Interview_Protocol>
Ask questions in rounds, not all at once. Start broad, then drill down.

### Round 1: Scope (2-3 questions)
- What is the primary goal?
- Who are the end users?
- What does success look like?

### Round 2: Data & Interactions (2-3 questions)
- What data does this involve?
- How do users interact with it?
- What are the main workflows?

### Round 3: Edge Cases (2-3 questions)
- What could go wrong?
- What are the boundary conditions?
- What should NOT happen?

### Round 4: Constraints (2-3 questions)
- Any tech stack preferences?
- Performance requirements?
- Timeline or budget constraints?
</Interview_Protocol>

<Output>
After the interview, produce a SPEC.md with:
- Problem statement
- Target users
- Core features (with priorities)
- User workflows
- Edge cases to handle
- Constraints
- Open questions (if any)

This spec becomes the input for planning or autopilot.
</Output>

<Ambiguity_Gate>
If after questioning, ambiguity is still > 20%, flag specific unknowns before proceeding.

If ambiguity is acceptable (< 20%), proceed to spec generation.
</Ambiguity_Gate>

<Examples>
<Good>
User: "deep-interview I want to build something for tracking my tasks"
Why good: Vague idea that needs clarification
</Good>

<Bad>
User: "deep-interview build a REST API for POST /users with body {name, email}"
Why bad: Requirements are already specific
</Bad>
</Examples>

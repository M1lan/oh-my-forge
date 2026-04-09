---
name: deep-interview
description: Socratic requirements clarification before any code is written
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

## INTERACTIVE QUESTIONING

**CRITICAL: Ask ONE question at a time. Wait for response before asking the next.**

Do NOT dump all questions at once. Each question must be followed by a response prompt:

```
❯ [question]

> _
```

After the user responds, analyze their answer, then ask the next relevant question.

## Question Sequence

### Step 1: Core Purpose
Ask ONE question:
> "What is the primary goal of this [feature]? What problem does it solve?"

Wait for response.

### Step 2: Users
Ask ONE question:
> "Who will be using this? (developers, end users, admins, etc.)"

Wait for response.

### Step 3: Scope
Based on answers, ask ONE focused question about scope:
> "What features are essential vs nice-to-have?"

Wait for response.

### Step 4: Technical Context
Based on answers, ask ONE question about tech:
> "Do you have existing preferences for [language/framework/database]?"

Wait for response.

### Step 5: Constraints
Ask ONE question about constraints:
> "Any specific requirements around [security/scale/compliance]?"

Wait for response.

### Step 6: Edge Cases
Ask ONE question about edge cases:
> "What should happen if [edge case]?"

Wait for response.

## Decision Gate

After all questions, if you have enough information (>80% clarity):

1. Generate SPEC.md with:
   - Problem statement
   - Target users
   - Core features (prioritized)
   - User workflows
   - Edge cases
   - Constraints

2. Then inform the user:
```
❯ SPEC.md generated. Here's what I understood:

## Summary
[2-3 sentences max]

## Core Features
1. [Feature 1] - Must have
2. [Feature 2] - Must have
3. [Feature 3] - Nice to have

## Next Step
Should I create a detailed PLAN.md with:
- File structure
- Tech stack recommendations
- Implementation steps
- Effort estimate

Type "yes" to proceed with the plan, or tell me if I missed something.
```

If unclear (>20% ambiguity):
> "I still have some open questions about [specific topics]. Let me ask..."

Ask remaining questions one by one.

## IMPORTANT: Do NOT Execute

After generating SPEC.md:
- Do NOT spawn frontend-design, autopilot, or any execution skill
- Do NOT write any code
- Wait for user confirmation to proceed with planning

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
Assistant: "What is the primary goal of this task tracker? What problem does it solve?"

User: "I want to track daily tasks and see my productivity over time"
Assistant: "Who will be using this tracker?"
...
Why good: One question at a time, builds understanding progressively
</Good>

<Bad>
User: "deep-interview build a REST API for POST /users with body {name, email}"
Why bad: Requirements are already specific - no interview needed
</Bad>
</Examples>

<Anti_Pattern>

## AVOID THIS

❌ DO NOT output all questions at once:

```
Round 1: Scope
1. What is the primary goal?
2. Who are the end users?
3. What does success look like?

Round 2: Technical
1. Tech stack?
2. Database preferences?
...
```

This overwhelms the user and prevents clarification.

## INSTEAD DO THIS

✅ Ask one, wait, ask next:

```
❯ What is the primary goal of this feature?

> user responds

❯ Who will be using it?

> user responds

❯ Any tech stack preferences?

> user responds
...
```

</Anti_Pattern>

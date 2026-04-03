---
name: team
description: Multi-agent coordinated execution
argument-hint: "<N:agent> <task description>"
level: 4
---

<Purpose>
Team orchestrates multiple specialized agents to work on a task in parallel. Each agent handles a different aspect, then results are synthesized into a cohesive solution.
</Purpose>

<Use_When>
- User says "team", "multiple agents", "coordinate"
- Complex task with distinct domains (frontend + backend + tests)
- User wants parallel expertise (security + performance + functionality)
- Large feature requiring parallel implementation streams
</Use_When>

<Do_Not_Use_When>
- Simple single-domain task
- Tasks requiring sequential thinking
- Quick fixes
</Do_Not_Use_When>

<Execution_Policy>
- Assign agents to distinct, non-overlapping responsibilities
- Agents work in parallel on their domains
- Synthesize results into unified solution
- Run integration tests after synthesis
</Execution_Policy>

<Steps>
1. **Analyze**: Break task into domains (frontend, backend, tests, docs, etc.)
2. **Assign**: Route each domain to the appropriate agent
3. **Execute**: Run agents in parallel
4. **Synthesize**: Combine outputs into cohesive solution
5. **Integrate**: Ensure parts work together
6. **Test**: Run full test suite

<Agent_Assignments>
| Domain | Agent |
|--------|-------|
| Architecture | @architect |
| Frontend | @ui-engineer, @style-expert |
| Backend | @api-designer, @db-engineer |
| Testing | @test-writer |
| Security | @security-reviewer |
| Performance | @perf-optimizer |
| Documentation | @doc-writer |
</Agent_Assignments>

<Examples>
<Good>
User: "team 3 @executor @test-writer @code-reviewer build user authentication"
Why good: Clear agent assignments, parallel workstreams
</Good>

<Good>
User: "team @architect design the system @backend implement API @frontend build UI"
Why good: Sequential pipeline with domain specialization
</Good>

<Bad>
User: "team 5 agents fix a typo"
Why bad: Overkill for simple task
</Bad>
</Examples>

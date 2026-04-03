---
name: scaffold
description: Generate project boilerplate from a description
argument-hint: "<project description>"
level: 2
---

<Purpose>
Scaffold generates a complete project structure from a brief description. It creates all necessary files, configs, and dependencies to get a running project quickly.
</Purpose>

<Use_When>
- User says "scaffold", "generate project", "boilerplate"
- Starting a new project from scratch
- Need a reference implementation
- Exploring a new framework or stack
</Use_When>

<Do_Not_Use_When>
- Extending existing project (use feature or migrate instead)
- User wants specific file structure
- Complex project needing deep planning first
</Do_Not_Use_When>

<Steps>
1. **Analyze**: Understand the project type and tech stack
2. **Propose**: Show the file tree structure
3. **Generate**: Create all boilerplate files
4. **Install**: Install dependencies
5. **Verify**: Confirm the project runs
</Steps>

<Output>
```
## Scaffold: [Project Name]

### File Tree
```
src/
├── main.ts
├── components/
├── utils/
├── types/
├── config/
├── api/
└── tests/
├── package.json
├── tsconfig.json
├── .env.example
└── README.md
```

### Tech Stack
- Runtime: [Node.js/Bun/Deno]
- Language: [TypeScript/Python/etc]
- Framework: [Express/FastAPI/etc]
- Testing: [Vitest/Pytest/etc]

### Generated Files
- [List of generated files with descriptions]
```

<Best_Practices>
- Include .gitignore with sensible defaults
- Include .env.example with all required vars
- Include README with setup instructions
- Include basic test setup
- Include linting/formatting config
</Best_Practices>

<Examples>
<Good>
User: "scaffold: REST API with Express and TypeScript, PostgreSQL, JWT auth"
Why good: Clear stack, understand requirements
</Good>

<Good>
User: "scaffold: React dashboard with charts and dark mode"
Why good: Clear UI direction
</Good>

<Bad>
User: "scaffold: something modern and fast"
Why bad: Too vague to scaffold effectively
</Bad>
</Examples>

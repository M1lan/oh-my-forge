# Design Systems

ForgeCode supports multiple design systems. Each design system is modular and can be used independently.

## Available Design Systems

| System | Style | Ownership | Best For |
|--------|-------|-----------|----------|
| [shadcn](./shadcn/) | Tailwind CSS | Copy-paste | React + Tailwind projects |
| [radix](./radix/) | Radix Primitives or Themes | Import | Custom or quick-start |
| [base-ui](./base-ui/) | Headless (any CSS) | Import | Modern, actively maintained |

---

## Comparison Matrix

| Aspect | shadcn/ui | Radix Themes | Base UI |
|--------|-----------|--------------|---------|
| **Style** | Tailwind CSS | CSS Variables | Any (Tailwind, CSS-in-JS, etc.) |
| **Ownership** | You own the code | npm import | npm import |
| **Maintenance** | Community | WorkOS | 7+ team (active) |
| **Components** | Curated 50+ | Full set | Extended set |
| **Customization** | Full (edit source) | Variable override | Full |
| **Learning curve** | Low | Low | Medium |

---

## Choosing a Design System

### Use shadcn/ui when

- Building with Next.js, Vite, or Remix
- Using Tailwind CSS
- Want "copy-paste-own" model
- Need excellent accessibility out of the box
- Want to own and customize every line of code

### Use Radix Themes when

- Quick prototyping
- Internal tools / admin dashboards
- Want styled components without design effort
- Using CSS Modules or CSS-in-JS

### Use Radix Primitives when

- Building a completely custom design system
- Need full control over every pixel
- Building on top of shadcn/ui

### Use Base UI when

- Need modern APIs and active development
- Building highly customized interfaces
- Using CSS-in-JS or CSS Modules (not Tailwind)
- Want more edge cases handled than Radix

---

## Quick Decision Tree

```text
Is your project using Tailwind CSS?
├── YES → Use shadcn/ui (recommended)
└── NO
    ├── Need quick/unstyled components?
    │   ├── YES → Use Radix Primitives
    │   └── NO
    │       ├── Want styled out-of-the-box?
    │       │   └── YES → Use Radix Themes
    │       └── Want modern/active maintenance?
    │           └── YES → Use Base UI
```

---

## Combining Design Systems

**Not recommended.** Pick one design system per project to maintain consistency.

If you need multiple:

1. Use Radix Primitives as the foundation
2. Layer shadcn/ui components on top
3. Use Base UI for specialized components only

---

## Adding a New Design System

To add a new design system:

```text
design-system/
└── your-system/
    ├── PHILOSOPHY.md   # Core principles
    ├── COMPONENTS.md   # Component usage
    ├── STYLING.md      # Styling patterns
    └── THEMES.md       # Theme customization (optional)
```

### Required Files

| File | Purpose |
|------|---------|
| `PHILOSOPHY.md` | Design principles and philosophy |
| `COMPONENTS.md` | Component usage patterns |
| `STYLING.md` | Styling approach and utilities |
| `THEMES.md` | Theming and customization (optional) |

---

## Design System Usage in ForgeCode

When working on a frontend task:

1. Check the project for existing design system
2. If none, ask user which design system to use
3. Reference the appropriate design system docs
4. Follow the philosophy and patterns

### Quick Reference

```text
Task → Identify design system → Follow patterns → Deliver
```

---

## Resources

### shadcn/ui

- Docs: <https://ui.shadcn.com>
- GitHub: <https://github.com/shadcn-ui/ui>
- Components: <https://ui.shadcn.com/docs/components>

### Radix UI

- Primitives: <https://www.radix-ui.com/primitives>
- Themes: <https://themes.radix-ui.com>
- GitHub: <https://github.com/radix-ui>

### Base UI

- Docs: <https://base-ui.com>
- GitHub: <https://github.com/mui/base-ui>
- Discord: <https://discord.gg/g6C3hUtuxz>

---

## Relationship Between Systems

```text
Base UI (successor to Radix)
    ↓
Radix Primitives (foundation)
    ↓
shadcn/ui (uses Radix + Tailwind)
```

**Note:** Base UI and shadcn/ui are both built with accessibility as a priority, but differ in styling approach and ownership model.

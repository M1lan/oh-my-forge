---
name: tailwind-v4
description: Tailwind CSS v4 migration and usage guide. Covers the CSS-first @theme paradigm, the @tailwindcss/vite plugin, auto-generated CSS variables, dark mode, and common migration traps (postcss.config.js + tailwind.config.js conflicts). Use when working in a project that already uses Tailwind v4, migrating from v3, scaffolding new styles, or debugging theme-token / build errors related to Tailwind.
---

# Tailwind CSS v4

This skill bundles reference material for Tailwind CSS v4 work. When loaded, read the companion files alongside this one:

- `PHILOSOPHY.md` -- core paradigm, `@theme` directive, migration from v3, Vite integration, DO/DON'T checklist.
- `UTILITIES.md` -- common utility patterns and examples.

## Quick checklist

Before writing any Tailwind v4 code in an unfamiliar project:

1. Confirm the project is on v4 -- look for `@import "tailwindcss"` (v4) vs `@tailwind base/components/utilities` (v3).
2. Check for conflicting config:
   - `tailwind.config.js` is ignored in v4 -- flag it as dead code.
   - `postcss.config.js` must use `@tailwindcss/postcss`, not `tailwindcss`, when PostCSS is the bundler.
   - When `@tailwindcss/vite` is in use, both `postcss.config.js` and `tailwind.config.js` should be removed.
3. Find the `@theme` block -- that is the single source of truth for design tokens.
4. Remember the naming convention: `--color-{name}` -> `bg-{name}/text-{name}/border-{name}`; `--spacing-{name}` -> `p-{name}/m-{name}/gap-{name}`; `--font-size-{name}` -> `text-{name}`.

## Critical rules

1. **Never** reintroduce `tailwind.config.js` into a v4 project.
2. **Never** mix `@tailwind base/components/utilities` with `@import "tailwindcss"`.
3. **Do** prefer `@theme` over manually declared CSS variables for design tokens -- v4 auto-generates both the variable and the utility classes.
4. **Do** use `@utility` to define custom utilities in CSS rather than plugin-style JS.
5. **Do** keep arbitrary-value escape hatches (`bg-[#ff5733]`) reserved for genuinely one-off values.

## When to invoke

Trigger this skill when any of these apply:

- The user is migrating an existing project from Tailwind v3 to v4.
- A build error mentions `@tailwindcss/vite`, `@tailwindcss/postcss`, `@theme`, or `@import "tailwindcss"`.
- You are asked to add or restructure design tokens in a Tailwind project.
- The user asks for "Tailwind best practices" in a project whose `package.json` shows `tailwindcss@^4`.

## Anti-patterns

- Shipping a `tailwind.config.js` alongside `@tailwindcss/vite`.
- Creating a separate `:root { --color-brand: ... }` declaration when the token belongs in `@theme`.
- Wrapping every class in `@apply` -- prefer utility classes directly in markup.
- Declaring dark-mode colors inside `@theme` instead of in a `.dark { ... }` overlay.

## See also

- `PHILOSOPHY.md` for the full v3 -> v4 migration reference and @theme examples.
- `UTILITIES.md` for a catalog of common utility patterns.

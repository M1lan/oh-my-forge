# Tailwind CSS v4

> The CSS-first configuration paradigm.

## Core Philosophy

Tailwind CSS v4 introduces a **CSS-native configuration** approach. Instead of a JavaScript config file, you configure your design system directly in CSS using `@theme`.

### Key Changes from v3

| Aspect | v3 | v4 |
|--------|-----|-----|
| Config location | `tailwind.config.js` | CSS with `@theme` |
| Build tool | PostCSS plugin | `@tailwindcss/vite` (or PostCSS) |
| Custom values | `extend` in config | Direct in `@theme` |
| Dark mode | Class strategy | `class` or `media` |
| Import | `@tailwind base/components/utilities` | `@import "tailwindcss"` |

---

## Migration from v3

### Old (v3)

```js
// tailwind.config.js
module.exports = {
  theme: {
    extend: {
      colors: {
        primary: '#3b82f6',
      },
      fontFamily: {
        sans: ['Inter', 'sans-serif'],
      },
    },
  },
}
```

### New (v4)

```css
/* main.css */
@import "tailwindcss";

@theme {
  --color-primary: #3b82f6;
  --font-family-sans: 'Inter', sans-serif;
}
```

---

## @theme Directive

The `@theme` block defines your design tokens:

```css
@theme {
  /* Colors */
  --color-primary: #3b82f6;
  --color-primary-hover: #2563eb;

  /* Typography */
  --font-family-display: 'Playfair Display', serif;
  --font-size-display: 4rem;
  --line-height-display: 1.1;

  /* Spacing */
  --spacing-128: 32rem;
  --spacing-144: 36rem;

  /* Border radius */
  --radius-lg: 1rem;
  --radius-xl: 1.5rem;

  /* Shadows */
  --shadow-card: 0 4px 6px -1px rgb(0 0 0 / 0.1);

  /* Animations */
  --animate-fade-in: fade-in 0.5s ease-out;
}
```

---

## CSS Variables Auto-Generation

In v4, **CSS variables are automatically generated** from your theme values:

```css
@theme {
  --color-brand: #ff5733;
}

/* Automatically generates: */
.bg-brand { background-color: var(--color-brand); }
.text-brand { color: var(--color-brand); }
.border-brand { border-color: var(--color-brand); }
```

### Naming Convention

```text
--color-{name}        → bg-{name}, text-{name}, border-{name}
--font-family-{name}  → font-{name}
--font-size-{name}    → text-{name}
--spacing-{name}      → p-{name}, m-{name}, gap-{name}
--radius-{name}       → rounded-{name}
```

---

## Arbitrary Values

### v3 Syntax

```html
<div class="bg-[#ff5733] p-[20px] text-[2.5rem]">
```

### v4 Syntax (unchanged)

```html
<div class="bg-[#ff5733] p-[20px] text-[2.5rem]">
```

---

## Dark Mode

```css
/* Light mode */
@theme {
  --color-bg: #ffffff;
  --color-text: #1a1a1a;
}

/* Dark mode */
.dark {
  --color-bg: #0a0a0a;
  --color-text: #f0f0f0;
}
```

### Usage

```html
<!-- Toggle dark mode -->
<div class="dark">
  <!-- Dark themed content -->
</div>
```

---

## Vite Integration

### Installation

```bash
npm install @tailwindcss/vite
```

### vite.config.js

```js
import { defineConfig } from 'vite'
import tailwindcss from '@tailwindcss/vite'

export default defineConfig({
  plugins: [tailwindcss()],
})
```

### Without Vite (PostCSS)

```bash
npm install -D tailwindcss @tailwindcss/postcss
```

```js
// postcss.config.js
module.exports = {
  plugins: {
    '@tailwindcss/postcss': {},
  },
}
```

---

## Utilities API (Advanced)

Create custom utilities in CSS:

```css
@utility bg-pattern {
  background-image: repeating-linear-gradient(
    45deg,
    var(--color-primary) 0,
    var(--color-primary) 2px,
    transparent 0,
    transparent 50%
  );
  background-size: 8px 8px;
}
```

---

## Key Features Summary

| Feature | Description |
|---------|-------------|
| `@theme` | CSS-native configuration |
| Auto CSS vars | Variables auto-generated from theme |
| Vite plugin | Faster builds with `@tailwindcss/vite` |
| `@utility` | Define custom utilities in CSS |
| `@apply` | Still supported |
| `@layer` | Still supported |
| Dark mode | CSS variables approach |

---

## DO's & DON'Ts

### DO

- [ ] Use `@theme` for design tokens
- [ ] Use `@utility` for custom utilities
- [ ] Leverage the Vite plugin for speed
- [ ] Use CSS variables for theming
- [ ] Keep custom CSS minimal
- [ ] **DELETE old config files** when upgrading from v3 or scaffold

### DON'T

- [ ] Don't use `tailwind.config.js` (unless legacy project)
- [ ] Don't use `@tailwind base/components/utilities` imports
- [ ] Don't manually define CSS variables for theme values
- [ ] Don't mix v3 and v4 patterns in same project
- [ ] **DON'T keep postcss.config.js** when using `@tailwindcss/vite`

---

## ⚠️ CRITICAL: Config File Conflicts

When using `@tailwindcss/vite` plugin, **REMOVE** these files:

```bash
# Remove these files - they conflict with @tailwindcss/vite
rm postcss.config.js
rm tailwind.config.js

# If using PostCSS instead of Vite plugin, install the correct package
npm install -D @tailwindcss/postcss  # NOT just "tailwindcss"

# Then postcss.config.js should ONLY contain:
module.exports = {
  plugins: {
    '@tailwindcss/postcss': {},
  },
}
```

### Why This Matters

- `postcss.config.js` with `tailwindcss` plugin → **Build error**
- `tailwind.config.js` → **Ignored in v4**
- `@tailwindcss/vite` → **Use this for Vite projects**

---

## Resources

- [Tailwind CSS v4 Docs](https://tailwindcss.com/docs/upgrade-guide)
- [V4 announcement](https://tailwindcss.com/blog/tailwindcss-v4-0)
- [Theme documentation](https://tailwindcss.com/docs/theme)

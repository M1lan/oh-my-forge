# Tailwind CSS v4 - Utilities & Patterns

## Installation

### Vite (Recommended)
```bash
npm install @tailwindcss/vite
```

```js
// vite.config.js
import tailwindcss from '@tailwindcss/vite'

export default {
  plugins: [tailwindcss()],
}
```

### PostCSS
```bash
npm install @tailwindcss/postcss
```

---

## Basic Setup

```css
/* main.css */
@import "tailwindcss";

@theme {
  /* Your design tokens */
  --color-primary: #3b82f6;
  --color-secondary: #64748b;
  --font-family-sans: 'Inter', system-ui, sans-serif;
}
```

---

## Color System

### Semantic Colors
```css
@theme {
  --color-background: #ffffff;
  --color-foreground: #1a1a1a;
  --color-muted: #f4f4f5;
  --color-muted-foreground: #71717a;
  --color-primary: #3b82f6;
  --color-primary-foreground: #ffffff;
  --color-secondary: #f4f4f5;
  --color-secondary-foreground: #18181b;
  --color-accent: #f4f4f5;
  --color-accent-foreground: #18181b;
  --color-destructive: #ef4444;
  --color-destructive-foreground: #ffffff;
  --color-border: #e4e4e7;
  --color-ring: #3b82f6;
}
```

### Usage
```html
<div class="bg-background text-foreground">
  <button class="bg-primary text-primary-foreground hover:bg-primary/90">
    Primary
  </button>
</div>
```

### Dark Mode
```css
.dark {
  --color-background: #09090b;
  --color-foreground: #fafafa;
  --color-muted: #27272a;
  --color-muted-foreground: #a1a1aa;
  --color-primary: #3b82f6;
  /* ... */
}
```

---

## Typography

### Font Families
```css
@theme {
  --font-family-sans: 'Inter', system-ui, sans-serif;
  --font-family-serif: 'Playfair Display', Georgia, serif;
  --font-family-mono: 'JetBrains Mono', ui-monospace, monospace;
}
```

### Type Scale
```css
@theme {
  --text-xs: 0.75rem;      /* 12px */
  --text-sm: 0.875rem;     /* 14px */
  --text-base: 1rem;       /* 16px */
  --text-lg: 1.125rem;     /* 18px */
  --text-xl: 1.25rem;      /* 20px */
  --text-2xl: 1.5rem;      /* 24px */
  --text-3xl: 1.875rem;    /* 30px */
  --text-4xl: 2.25rem;     /* 36px */
}
```

### Usage
```html
<h1 class="font-sans text-4xl font-bold tracking-tight">
  Heading
</h1>
<p class="font-serif text-lg leading-relaxed">
  Article text
</p>
<code class="font-mono text-sm bg-muted px-1 py-0.5 rounded">
  inline code
</code>
```

---

## Spacing

### Custom Spacing
```css
@theme {
  --spacing-18: 4.5rem;    /* 72px */
  --spacing-88: 22rem;     /* 352px */
}
```

### Common Patterns
```html
<!-- Card padding -->
<div class="p-6">

<!-- Section gap -->
<section class="gap-4">

<!-- Page margins -->
<main class="container mx-auto px-4">

<!-- Stack -->
<div class="flex flex-col gap-4">
```

---

## Layout

### Container
```css
.container {
  width: 100%;
  margin-inline: auto;
  padding-inline: 1rem;
}

@media (min-width: 640px) {
  .container { max-width: 640px; }
}
@media (min-width: 768px) {
  .container { max-width: 768px; }
}
@media (min-width: 1024px) {
  .container { max-width: 1024px; }
}
@media (min-width: 1280px) {
  .container { max-width: 1280px; }
}
```

### Grid
```html
<!-- Auto-responsive grid -->
<div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
  <!-- Cards -->
</div>

<!-- Sidebar layout -->
<div class="grid lg:grid-cols-[250px_1fr] gap-6">
  <aside>Sidebar</aside>
  <main>Content</main>
</div>
```

### Flexbox
```html
<!-- Center content -->
<div class="flex items-center justify-center">

<!-- Between -->
<div class="flex items-center justify-between">

<!-- Stack vertical -->
<div class="flex flex-col gap-4">
```

---

## Components

### Button
```css
@utility btn-base {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
  border-radius: var(--radius-md);
  font-weight: 500;
  padding: 0.5rem 1rem;
  transition: background-color 0.15s;
}

@utility btn-primary {
  background-color: var(--color-primary);
  color: var(--color-primary-foreground);
}

@utility btn-primary:hover {
  background-color: var(--color-primary)/90;
}
```

### Card
```html
<div class="rounded-lg border bg-background shadow-sm">
  <div class="p-6">
    <h3 class="text-lg font-semibold">Card Title</h3>
    <p class="text-muted-foreground">Card description</p>
  </div>
</div>
```

### Form Input
```html
<input
  type="text"
  class="flex h-10 w-full rounded-md border border-input bg-background px-3 py-2 text-sm ring-offset-background file:border-0 file:bg-transparent file:text-sm file:font-medium placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50"
/>
```

---

## Animation

### Transitions
```html
<!-- Hover transitions -->
<button class="transition-colors hover:bg-primary/90">
<button class="transition-transform hover:scale-105">
<button class="transition-all hover:shadow-lg">
```

### Keyframes
```css
@theme {
  --animate-fade-in: fade-in 0.3s ease-out;
  --animate-slide-in: slide-in 0.3s ease-out;
}

@keyframes fade-in {
  from { opacity: 0; }
  to { opacity: 1; }
}

@keyframes slide-in {
  from { transform: translateY(-10px); opacity: 0; }
  to { transform: translateY(0); opacity: 1; }
}
```

### Usage
```html
<div class="animate-fade-in">
  Content fades in
</div>
```

---

## Responsive Design

### Breakpoints
| Name | Min-width | Use |
|------|-----------|-----|
| `sm` | 640px | Large phones |
| `md` | 768px | Tablets |
| `lg` | 1024px | Laptops |
| `xl` | 1280px | Desktops |
| `2xl` | 1536px | Large screens |

### Mobile-First
```html
<!-- Mobile first, enhance on larger -->
<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4">

<!-- Stack mobile, row desktop -->
<div class="flex flex-col md:flex-row gap-4">
```

---

## Arbitrary Values

### Colors
```html
<div class="bg-[#ff5733] text-[#fffafa]">
```

### Sizes
```html
<div class="w-[calc(100%-1rem)] p-[20px] text-[2.5rem]">
```

### Custom Properties
```html
<div class="[--my-color:#ff5733] bg-[--my-color]">
```

---

## Best Practices

### DO
```html
<!-- Use semantic tokens -->
<div class="bg-primary text-primary-foreground">

<!-- Use spacing scale -->
<div class="p-4 gap-2">

<!-- Use responsive prefixes -->
<div class="grid md:grid-cols-2">

<!-- Use dark: prefix -->
<div class="dark:bg-background">
```

### DON'T
```html
<!-- Avoid hardcoded colors -->
<div class="bg-red-500 text-white">

<!-- Avoid arbitrary values when theme exists -->
<div class="p-[16px]">

<!-- Avoid !important -->
<div class="!bg-red-500">
```

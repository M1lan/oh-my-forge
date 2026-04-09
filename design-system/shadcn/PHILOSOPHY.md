# shadcn/ui Design System

> Philosophy: **"Copy, paste, own"** - Unlike traditional component libraries, shadcn/ui is not a package you install. You copy components into your project and own them.

## Core Philosophy

### 1. Not a Component Library

- **NOT** a npm package to install
- **NOT** a theme to configure
- **IS** a collection of copy-paste components you own

### 2. Ownership Model

```text
You → own → your-components/
  ├── button.tsx
  ├── dialog.tsx
  ├── form.tsx
  └── ...
```

- Modify freely
- Full control over styling
- No external dependencies breaking your UI

### 3. Stack

| Layer | Technology |
|-------|------------|
| Styling | Tailwind CSS |
| Primitives | Radix UI |
| Animation | Framer Motion |
| Forms | React Hook Form + Zod |

---

## Design Principles

### Clarity First

- Components are stripped to essential functionality
- Remove opinionated styling, keep semantic structure
- Use CSS variables for theming, not hardcoded values

### Composition Over Configuration

**BAD:**

```tsx
<Button variant="primary" size="large" rounded={true} />
```

**GOOD:**

```tsx
<Button className="bg-primary text-primary-foreground hover:bg-primary/90">
  Click me
</Button>
```

### Accessibility is Mandatory

- All components use Radix primitives
- Full keyboard navigation
- Screen reader support built-in
- ARIA attributes handled

---

## Color System

### Semantic Colors

```css
--background      /* Page background */
--foreground      /* Text color */
--card           /* Card surfaces */
--card-foreground
--primary        /* Primary actions */
--primary-foreground
--secondary      /* Secondary elements */
--secondary-foreground
--muted          /* Subtle backgrounds */
--muted-foreground
--accent         /* Hover/highlight states */
--accent-foreground
--destructive    /* Error/danger states */
--destructive-foreground
--border
--ring           /* Focus rings */
```

### Usage Rules

1. Use semantic colors, not raw values
2. Primary = one per project
3. Destructive only for dangerous actions

---

## Typography Scale

| Name | Size | Usage |
|------|------|-------|
| `h1` | 3rem (48px) | Page titles |
| `h2` | 2rem (32px) | Section headers |
| `h3` | 1.5rem (24px) | Card titles |
| `h4` | 1.25rem (20px) | Subsections |
| `p` | 1rem (16px) | Body text |
| `small` | 0.875rem (14px) | Captions |
| `muted` | 0.875rem (14px) | Secondary text |

---

## Spacing System

### Tailwind Default Scale

```css
0: 0px
1: 4px
2: 8px
3: 12px
4: 16px
5: 20px
6: 24px
8: 32px
10: 40px
12: 48px
16: 64px
```

### Common Patterns

| Pattern | Classes | Usage |
|---------|---------|-------|
| Card padding | `p-6` | Standard card |
| Section gap | `gap-4` | Between elements |
| Page margin | `container mx-auto px-4` | Page layout |
| Stack | `flex flex-col gap-4` | Vertical lists |

---

## Component Patterns

### Button

```tsx
// Primary action
<Button>Save changes</Button>

// Destructive
<Button variant="destructive">Delete</Button>

// Ghost (minimal)
<Button variant="ghost">Cancel</Button>

// Icon only
<Button size="icon" variant="ghost">
  <Trash className="h-4 w-4" />
</Button>
```

### Card

```tsx
<Card>
  <CardHeader>
    <CardTitle>Settings</CardTitle>
    <CardDescription>Manage your preferences</CardDescription>
  </CardHeader>
  <CardContent>
    {/* content */}
  </CardContent>
  <CardFooter>
    <Button>Save</Button>
  </CardFooter>
</Card>
```

### Form

```tsx
<FormField
  control={form.control}
  name="email"
  render={({ field }) => (
    <FormItem>
      <FormLabel>Email</FormLabel>
      <FormControl>
        <Input placeholder="<you@example.com>" {...field} />
      </FormControl>
      <FormDescription>We'll never share your email.</FormDescription>
      <FormMessage />
    </FormItem>
  )}
/>
```

---

## Dark Mode

### Implementation

```tsx
// Tailwind dark mode class strategy
<div className="dark">
  {/* Dark theme content */}
</div>

// Or: dark mode variant
<Button className="bg-white text-black dark:bg-zinc-900 dark:text-white" />
```

### Color Variables for Dark Mode

```css
.dark {
  --background: 0 0% 100%;
  --foreground: 0 0% 3.9%;
  /* ... auto-adjusted via CSS */
}
```

---

## Motion & Animation

### When to Animate

| Animation | Purpose |
|-----------|---------|
| `fade-in` | Content appearing |
| `slide-in` | Modals, drawers |
| `scale-in` | Dropdowns, popovers |
| `press` | Button clicks |

### Framer Motion Usage

```tsx
<motion.div
  initial={{ opacity: 0, y: 10 }}
  animate={{ opacity: 1, y: 0 }}
  transition={{ duration: 0.2 }}
>
  Content
</motion.div>
```

### Timing

| Duration | Usage |
|----------|-------|
| `150ms` | Hover states, micro-interactions |
| `200ms` | Toggles, selections |
| `300ms` | Modals, sheets |
| `500ms` | Page transitions |

---

## File Structure

```text
src/
├── components/ui/     # shadcn/ui components (owned)
│   ├── button.tsx
│   ├── card.tsx
│   ├── dialog.tsx
│   └── ...
├── lib/
│   └── utils.ts       # cn() utility
└── app/
    └── page.tsx       # Your app code
```

---

## DO's & DON'Ts

### DO

- [ ] Copy components, don't import from npm
- [ ] Use semantic color variables
- [ ] Compose small components into bigger ones
- [ ] Use `cn()` for conditional classes
- [ ] Test keyboard navigation
- [ ] Use variants sparingly

### DON'T

- [ ] Don't nest too many variants
- [ ] Don't override component internals
- [ ] Don't mix design systems (pick one)
- [ ] Don't use !important in component code
- [ ] Don't skip the Radix primitives

---

## Resources

- [shadcn/ui Docs](https://ui.shadcn.com)
- [Radix UI Primitives](https://www.radix-ui.com)
- [Tailwind CSS](https://tailwindcss.com)
- [Framer Motion](https://www.framer.com/motion/)

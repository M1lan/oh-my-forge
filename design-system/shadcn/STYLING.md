# Styling Patterns

## Utility Classes

### cn() Helper

```tsx
import { type ClassValue, clsx } from "clsx"
import { twMerge } from "tailwind-merge"

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

// Usage
<div className={cn(
  "base-class",
  condition && "conditional-class",
  "h-10 px-4 py-2"
)} />
```

### Tailwind Configuration

```js
// tailwind.config.js
/** @type {import('tailwindcss').Config} */
module.exports = {
  darkMode: ["class"],
  content: [
    "./pages/**/*.{ts,tsx}",
    "./components/**/*.{ts,tsx}",
    "./app/**/*.{ts,tsx}",
    "./src/**/*.{ts,tsx}",
  ],
  theme: {
    container: {
      center: true,
      padding: "2rem",
      screens: {
        "2xl": "1400px",
      },
    },
    extend: {
      colors: {
        border: "hsl(var(--border))",
        input: "hsl(var(--input))",
        ring: "hsl(var(--ring))",
        background: "hsl(var(--background))",
        foreground: "hsl(var(--foreground))",
        primary: {
          DEFAULT: "hsl(var(--primary))",
          foreground: "hsl(var(--primary-foreground))",
        },
        secondary: {
          DEFAULT: "hsl(var(--secondary))",
          foreground: "hsl(var(--secondary-foreground))",
        },
        // ... etc
      },
      borderRadius: {
        lg: "var(--radius)",
        md: "calc(var(--radius) - 2px)",
        sm: "calc(var(--radius) - 4px)",
      },
    },
  },
  plugins: [require("tailwindcss-animate")],
}
```

---

## CSS Variables

### Global Styles

```css
@tailwind base;
@tailwind components;
@tailwind utilities;

@layer base {
  :root {
    --background: 0 0% 100%;
    --foreground: 222.2 84% 4.9%;
    --card: 0 0% 100%;
    --card-foreground: 222.2 84% 4.9%;
    --popover: 0 0% 100%;
    --popover-foreground: 222.2 84% 4.9%;
    --primary: 222.2 47.4% 11.2%;
    --primary-foreground: 210 40% 98%;
    --secondary: 210 40% 96.1%;
    --secondary-foreground: 222.2 47.4% 11.2%;
    --muted: 210 40% 96.1%;
    --muted-foreground: 215.4 16.3% 46.9%;
    --accent: 210 40% 96.1%;
    --accent-foreground: 222.2 47.4% 11.2%;
    --destructive: 0 84.2% 60.2%;
    --destructive-foreground: 210 40% 98%;
    --border: 214.3 31.8% 91.4%;
    --input: 214.3 31.8% 91.4%;
    --ring: 222.2 84% 4.9%;
    --radius: 0.5rem;
  }

  .dark {
    --background: 222.2 84% 4.9%;
    --foreground: 210 40% 98%;
    /* ... adjusted values for dark mode */
  }
}

@layer base {
  * {
    @apply border-border;
  }
  body {
    @apply bg-background text-foreground;
  }
}
```

---

## Responsive Patterns

### Mobile-First

```tsx
// Mobile first, expand to desktop
<div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
  {/* Cards */}
</div>

// Stack on mobile, row on desktop
<div className="flex flex-col md:flex-row gap-4">
  <Sidebar />
  <Content />
</div>
```

### Breakpoints

| Name | Min-width | Usage |
|------|-----------|-------|
| `sm` | 640px | Large phones |
| `md` | 768px | Tablets |
| `lg` | 1024px | Laptops |
| `xl` | 1280px | Desktops |
| `2xl` | 1536px | Large screens |

---

## Animation Classes

### Tailwind + Animate

```tsx
<div className="animate-in fade-in slide-in-from-bottom-4 duration-200">
  Content
</div>

// With variants
<motion.div
  initial={{ opacity: 0, y: 20 }}
  animate={{ opacity: 1, y: 0 }}
  className="..."
/>
```

### Common Animations

| Class | Effect |
|-------|--------|
| `animate-in` | Fade in |
| `fade-in` | Opacity 0 to 1 |
| `slide-in-from-bottom` | Slide up |
| `slide-in-from-left` | Slide right |
| `zoom-in-95` | Scale 95% to 100% |
| `spin-in-90` | Rotate 90 deg |
| `duration-200` | 200ms timing |

---

## Layout Patterns

### Container

```tsx
<div className="container mx-auto px-4">
  {/* Page content */}
</div>
```

### Centered Content

```tsx
<div className="flex min-h-screen items-center justify-center">
  <Card>Content</Card>
</div>
```

### Sidebar Layout

```tsx
<div className="flex h-screen">
  <aside className="w-64 hidden md:block">
    <Sidebar />
  </aside>
  <main className="flex-1 overflow-auto">
    <Header />
    <div className="p-6">
      {children}
    </div>
  </main>
</div>
```

### Grid Auto-fit

```tsx
// Auto-responsive grid
<div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
  {/* Items */}
</div>
```

---

## Common Patterns

### Hover States

```tsx
<Button className="hover:bg-primary/90 transition-colors">
  Hover me
</Button>
```

### Focus Rings

```tsx
// Always visible focus for accessibility
<Button className="focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring">
  Focus
</Button>
```

### Disabled States

```tsx
<Button disabled className="opacity-50 cursor-not-allowed">
  Disabled
</Button>
```

### Loading States

```tsx
<div className="flex items-center gap-2">
  <Loader2 className="h-4 w-4 animate-spin" />
  <span>Loading...</span>
</div>
```

---

## Typography Styles

### Heading

```tsx
<h1 className="text-3xl font-bold tracking-tight">
  Title
</h1>
<h2 className="text-2xl font-semibold tracking-tight">
  Section
</h2>
<h3 className="text-xl font-semibold">
  Subsection
</h3>
```

### Body

```tsx
<p className="leading-7">
  Body text with good line height for readability.
</p>
<p className="text-sm text-muted-foreground">
  Secondary / muted text
</p>
```

### Code

```tsx
<code className="relative rounded bg-muted px-[0.3rem] py-[0.2rem] font-mono text-sm font-semibold">
  code
</code>
<pre className="rounded-lg border bg-card">
  <code>Code block</code>
</pre>
```

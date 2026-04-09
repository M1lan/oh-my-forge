# Radix UI

> Open source component library maintained by [WorkOS](https://workos.com).

## Two Products

Radix now offers two distinct products:

| Product | Description | Style |
|---------|-------------|-------|
| **Radix Primitives** | Unstyled, accessible components | None (bring your own) |
| **Radix Themes** | Styled, opinionated components | Opinionated design |

---

## Radix Primitives

### Philosophy

- **Unstyled by default** - You bring the design
- **Accessible by default** - WAI-ARIA compliant
- **Composable** - Small, focused primitives

### When to Use

- Building a custom design system
- Need full control over styling
- Creating highly customized components
- Foundation for shadcn/ui

### Categories

| Category | Components |
|----------|------------|
| Accessibility | `Dialog`, `Dropdown Menu`, `Popover`, `Tooltip` |
| Forms | `Checkbox`, `Radio Group`, `Switch`, `Toggle Group` |
| Navigation | `Navigation Menu`, `Tabs`, `Context Menu` |
| Overlay | `Alert Dialog`, `Hover Card`, `Scroll Area` |
| Collection | `Accordion`, `Slider`, `Progress` |

---

## Radix Themes

### Philosophy

- **Styled by default** - Ready to use out of the box
- **CSS Variables** - Easy to customize
- **Accessible** - WAI-ARIA compliant

### When to Use

- Quick prototyping
- Internal tools
- Admin dashboards
- When you want styled but not opinionated

### Example

```tsx
import "@radix-ui/themes/styles.css";
import { Theme, Button } from "@radix-ui/themes";

export default () => (
  <Theme>
    <Button>Hey</Button>
  </Theme>
);
```

---

## shadcn/ui vs Radix

| Aspect | shadcn/ui | Radix Primitives | Radix Themes |
|--------|-----------|------------------|-------------|
| Style | Tailwind | None | CSS Variables |
| Ownership | Copy-paste | Import | Import |
| Customization | Full | Full | Variable override |
| Components | Curated set | Full set | Full set |

**Note:** shadcn/ui is built on top of Radix Primitives.

---

## Resources

- [Radix UI Docs](https://www.radix-ui.com)
- [Radix Themes](https://themes.radix-ui.com)
- [GitHub](https://github.com/radix-ui)

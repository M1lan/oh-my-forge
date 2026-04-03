# Base UI

> Unstyled UI components for building accessible user interfaces.
> Created by the team behind Radix UI, Floating UI, and Material UI.

## Overview

Base UI is a comprehensive React component library built by the same team that created Radix UI. It represents the next generation of headless components with improved APIs and active development.

**Key distinction:** Base UI is actively maintained by a dedicated team of 7+ developers, designers, and managers. This is the successor to Radix Primitives.

## Philosophy

- **Unstyled/Headless** - Full style control, no opinions
- **Accessible** - WAI-ARIA compliant, WCAG 2.2 standard
- **Composable** - Small, focused primitives
- **Modern** - Uses latest React patterns

## Stack

| Layer | Technology |
|-------|------------|
| Framework | React 18+ |
| Styling | Any CSS solution (Tailwind, CSS Modules, CSS-in-JS) |
| Animation | Any library (Motion, Framer Motion, CSS) |

## Key Components

| Category | Components |
|----------|------------|
| Inputs | `Button`, `Switch`, `Checkbox`, `Radio` |
| Popovers | `Menu`, `Popover`, `Tooltip`, `HoverCard` |
| Dialogs | `Dialog`, `Alert Dialog`, `Modal` |
| Selection | `Select`, `Combobox`, `Autocomplete` |
| Data | `DataTable`, `Pagination` |
| Layout | `Accordion`, `Collapsible`, `Separator` |

## When to Use Base UI

### Use Base UI When
- Building a custom design system from scratch
- Need components not in shadcn/ui
- Using CSS-in-JS or CSS Modules (not Tailwind)
- Want active maintenance and new features
- Building highly customized interfaces

### Use shadcn/ui Instead When
- Using Tailwind CSS
- Need rapid development
- Want "copy-paste-own" model
- Need a curated component set

## Base UI vs Radix Primitives

| Aspect | Base UI | Radix Primitives |
|--------|---------|------------------|
| Maintenance | Active (7+ team) | Limited |
| API | Modern | Legacy |
| Components | Extended set | Core set |
| Features | More edge cases handled | Basic functionality |
| Future | Active development | Maintenance mode |

## Example

```tsx
import { Accordion, AccordionItem, AccordionTrigger, AccordionPanel } from '@base-ui/react';

function FAQ() {
  return (
    <Accordion defaultValue="item-1">
      <AccordionItem value="item-1">
        <AccordionTrigger>What is Base UI?</AccordionTrigger>
        <AccordionPanel>
          A comprehensive UI component library for React.
        </AccordionPanel>
      </AccordionItem>
    </Accordion>
  );
}
```

## Companies Using Base UI

- Paper
- GitHub
- Zed
- Unsplash
- And more...

## Resources
- [Base UI Docs](https://base-ui.com)
- [Base UI GitHub](https://github.com/mui/base-ui)
- [Discord Community](https://discord.gg/g6C3hUtuxz)
- [npm Package](https://www.npmjs.com/package/@base-ui/react)

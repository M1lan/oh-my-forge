---
name: visual-verdict
description: Evaluate a UI against a reference (screenshot, design mockup, or prior state) and deliver a concrete verdict. Identifies layout drift, color drift, typography issues, spacing anomalies, accessibility failures, and responsive breakage. Use after a visual change has been made, when the user provides a reference image, or when verifying a design implementation matches intent.
---

# Visual Verdict

Disciplined visual QA for UI work.

## When to invoke

- A UI change was just made and needs verification.
- The user provides a reference image, Figma screenshot, or prior state and asks "does it match".
- A design implementation task is marked complete and needs a final check.
- The user says "look at this", "compare", "does it look right".

## Inputs

1. **Target**: the current implementation (running app, screenshot, or rendered HTML/CSS).
2. **Reference**: the desired state (design mockup, screenshot, or previous working version).
3. **Scope**: which page / component / breakpoint is under review.

## Evaluation dimensions

1. **Layout fidelity** -- does the box model match? (widths, heights, alignment, grid/flex behavior)
2. **Color** -- do colors match, including hover/focus/disabled states? (use hex, not "blue")
3. **Typography** -- font family, size, weight, line-height, letter-spacing, truncation behavior.
4. **Spacing** -- padding, margin, gap. Spot inconsistent spacing scales.
5. **Interactive states** -- hover, focus, active, disabled, loading, error. Are they all present and correct?
6. **Responsive** -- does it work at all breakpoints? Small viewport, tablet, large desktop.
7. **Accessibility** -- color contrast (WCAG AA/AAA), focus indicators, keyboard navigation, alt text, semantic HTML, ARIA.
8. **Dark mode** -- if the project supports it, does it work in dark mode too?
9. **Motion** -- transitions, animations, durations, easing. Do they feel right or jarring?
10. **Edge cases** -- long text, empty states, loading states, error states, slow network.

## Workflow

1. Obtain the reference and the target. If either is missing, ask for it.
2. Score each dimension: PASS / MINOR / BLOCKING.
3. For every MINOR or BLOCKING, cite the exact `path:line` in the source and name the concrete fix.
4. Emit the verdict.

## Verdict vocabulary

- **APPROVE** -- ships. All dimensions PASS or have only acceptable MINORs documented.
- **ITERATE** -- close but one or more MINORs must be fixed.
- **REJECT** -- at least one BLOCKING issue exists.

## Rules

- Be specific. "Spacing is off" is not feedback. "The card has 16px padding but the reference uses 24px; update `card.css:12`" is.
- Always name colors in hex.
- Always name sizes in the unit the codebase uses (px, rem, em, tw spacing scale).
- Accessibility failures are ALWAYS BLOCKING (contrast, keyboard trap, missing focus).
- Do NOT suggest a full rewrite unless the implementation is fundamentally wrong.

## Output

```text
## Visual Verdict: APPROVE | ITERATE | REJECT

### Scope
{page / component / breakpoint}

### Dimensions
| Dimension | Status | Notes |
|---|---|---|
| Layout | PASS / MINOR / BLOCKING | ... |
| Color | ... | ... |
| Typography | ... | ... |
| Spacing | ... | ... |
| States | ... | ... |
| Responsive | ... | ... |
| Accessibility | ... | ... |
| Dark mode | ... | ... |
| Motion | ... | ... |
| Edge cases | ... | ... |

### Blocking issues
1. path:line -- what is wrong -- what to do

### Minor issues
- path:line -- ...

### What is good
- ...
```

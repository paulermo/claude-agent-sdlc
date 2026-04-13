# Design System

## Design-System-First Workflow

Before implementing any UI feature, follow this decision tree:

1. **Does this need a new design token?** → Add to the token file first
2. **Does this need a new UI primitive?** → Create in `components/ui/` first
3. **Only then** wire into the feature component or page

Never skip tiers. A feature component must not define its own colors, shadows, or spacing values — it uses tokens and UI primitives.

## Token Architecture

All visual values are defined as tokens (CSS custom properties, theme objects, or equivalent):

```css
:root {
  /* Colors */
  --color-primary: #...;
  --color-secondary: #...;
  --color-surface: #...;
  --color-text: #...;
  --color-error: #...;

  /* Spacing */
  --space-xs: 4px;
  --space-sm: 8px;
  --space-md: 16px;
  --space-lg: 24px;
  --space-xl: 32px;

  /* Typography */
  --font-size-sm: 0.875rem;
  --font-size-md: 1rem;
  --font-size-lg: 1.25rem;

  /* Shadows, radii, transitions... */
}
```

## Dark Mode

Use CSS custom properties with a theme attribute:

```css
[data-theme="dark"] {
  --color-surface: #1a1a1a;
  --color-text: #e0e0e0;
  /* Override only color tokens — spacing, typography stay the same */
}
```

## Anti-patterns

- **Hardcoded hex values in components** — always use tokens
- **Inline styles** — never use `style={{}}` attributes
- **Skipping tiers** — a page should not use raw CSS for a button; use the Button primitive
- **One-off component styles** — if you need a visual variation, it probably belongs as a variant in the design system, not a custom override

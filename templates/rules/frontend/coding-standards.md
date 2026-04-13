# Frontend Coding Standards

## TypeScript

- **Strict mode enabled** — no `any`, no implicit `any`, strict null checks
- **Explicit return types** on exported functions
- **Discriminated unions** over type assertions
- **`unknown` over `any`** for truly unknown types — then narrow with type guards

## Naming Conventions

| Kind | Convention | Example |
|------|-----------|---------|
| Components | PascalCase | `UserProfile`, `CheckoutForm` |
| Hooks | camelCase with `use` prefix | `useAuth`, `useProducts` |
| Utilities | camelCase | `formatCurrency`, `parseDate` |
| Constants | UPPER_SNAKE_CASE | `MAX_RETRY_COUNT`, `API_BASE_URL` |
| Types/Interfaces | PascalCase | `UserDto`, `ProductFilter` |
| Files (components) | PascalCase | `UserProfile.tsx` |
| Files (utilities) | camelCase | `formatCurrency.ts` |

## Styling

- **No inline styles** — never use `style={{}}` or inline style attributes. Zero exceptions.
- **Use CSS classes** or CSS-in-JS with design tokens
- **Design tokens for all visual values** — colors, spacing, shadows, border-radius, font sizes
- **No hardcoded hex/rgb values** in component files — use token references

## Accessibility

- **Semantic HTML** — use `<button>`, `<nav>`, `<main>`, `<article>` correctly
- **ARIA attributes** only when semantic HTML is insufficient
- **Keyboard navigation** — all interactive elements reachable and operable via keyboard
- **Focus management** — visible focus indicators, logical tab order
- **Alt text** for images, `aria-label` for icon buttons

## Testing

- **Unit tests** for utilities, hooks, and business logic
- **Component tests** for interactive behavior (user events, state changes)
- **Integration tests** for API-dependent flows (mock at the network level, not at the module level)
- **Test user behavior, not implementation** — test what the user sees and does, not internal state

# Frontend Architecture

## Component Tiers

Organize components in three tiers with strict dependency direction:

```
Pages → Feature Components → UI Primitives
```

### Tier 1: UI Primitives
- Generic, reusable components with no business logic
- Examples: Button, Input, Card, Modal, Table
- Styled using design tokens only — no hardcoded values
- Located in `components/ui/` or equivalent

### Tier 2: Feature Components
- Compose UI primitives into business-meaningful units
- Contain domain logic, data fetching, state management
- Examples: UserProfile, ProductCard, CheckoutForm
- Located in feature directories

### Tier 3: Pages
- Compose feature components into full routes/views
- Handle routing, layout, data loading orchestration
- Minimal logic — primarily composition and coordination

## Server vs Client Components

If using a server-component framework (Next.js App Router, etc.):

- **Default to server components** — they render on the server, reduce client bundle
- **Use client components only when needed** — interactivity, browser APIs, state, effects
- **Keep client boundaries small** — wrap only the interactive part, not the whole page
- **Data fetching in server components** — pass data down as props to client components

## State Management

- **Server state**: Use data fetching library (React Query, SWR, etc.) — don't duplicate server state in client stores
- **Client state**: Use component-local state first, lift to context/store only when shared across distant components
- **URL state**: Pagination, filters, tabs → URL search params (shareable, bookmarkable)
- **Form state**: Use form library or controlled components — don't sync forms with global state

## API Integration

- All API calls go through a single gateway/client module
- Never call APIs directly from components — use hooks/services
- Handle loading, error, and empty states for every async operation
- Follow API conventions from `docs/rules/api/standards.md`

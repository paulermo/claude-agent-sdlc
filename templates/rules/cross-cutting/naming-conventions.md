# Naming Conventions

## Domain Method Naming

Domain service interfaces, entity guard methods, and factory validation methods use **`ensure`** — never `assert`.

`assert` is a testing/technical term. In domain code, **`ensure`** communicates business intent: "make sure this invariant holds."

### Where this applies

- Domain service interface methods: `ensureUnique()`, `ensureCanPublish()`
- Entity guard methods: `ensureDeletable()`, `ensureValueValid()`
- Factory validation methods: `ensureNameUnique()`, `ensureNotDuplicate()`

### Where this does NOT apply

- Test assertions (`assertSame(...)`, `assert result == ...`) — these ARE test assertions
- Framework validation attributes — framework metadata, not domain naming
- Infrastructure code that wraps test/framework tools

## General Naming Principles

- **Be descriptive over brief**: `calculateTotalPrice()` over `calcTP()`
- **Use domain language**: name things after business concepts, not technical implementation
- **Avoid abbreviations**: unless universally understood (`id`, `url`, `http`)
- **Boolean methods/properties**: use `is`, `has`, `can`, `should` prefixes
- **Collections**: use plural nouns (`users`, `orders`, `items`)
- **Factory methods**: use `create`, `from`, `of` prefixes
- **Conversion methods**: use `to` prefix (`toString()`, `toArray()`, `toDto()`)

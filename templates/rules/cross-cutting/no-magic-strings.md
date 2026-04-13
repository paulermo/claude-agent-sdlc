# No Magic Strings — Use Constants, Enums, or Named References

String literals repeated across files or carrying domain meaning must be replaced with a named constant, enum, or configuration reference. A "magic string" is any literal that a developer must know the exact spelling of to use correctly.

## What counts as a magic string

- Error codes, status values, classification labels
- Storage keys (localStorage, sessionStorage, Redis)
- Event names and message types
- Feature flags and config keys
- Repeated route prefixes or external URLs
- Any string compared with `===`, `==`, `match`, `switch`, or `if`

## What does NOT count

- One-off display text, log messages, exception messages for humans
- Framework attribute arguments that reference config identifiers
- Test assertion strings (`$this->assertSame('expected', ...)`, `assert result == 'expected'`)

## Language-specific guidance

**TypeScript/JavaScript:** Use `const` objects or string literal union types. Place shared constants in a `constants/` directory. Name in `UPPER_SNAKE_CASE`.

**Python:** Use `StrEnum` for fixed sets. Use module-level `UPPER_SNAKE_CASE` constants for standalone values.

**Go:** Use typed constants or `iota` for fixed sets.

**PHP:** Use backed enums for fixed sets (statuses, types, classifications). Use class constants for standalone values.

**Rust:** Use enums. Derive `Display` and `FromStr` for string representation.

## Examples

```typescript
// Bad — magic string repeated across files
if (status === 'enabled') { ... }

// Good — enum/const carries the meaning
if (status === Status.Enabled) { ... }
```

```python
# Bad — magic string in comparison
if event_type == "product_updated": ...

# Good — enum member
if event_type == EventType.PRODUCT_UPDATED: ...
```

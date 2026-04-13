# Product Conventions

## Feature Specification Structure

Every feature spec includes:

### Required Header Fields

```yaml
---
id: {PREFIX}-FEATURE-{N}
status: draft | ready | in-progress | done
priority: critical | high | medium | low
depends-on: [list of feature IDs]
blocks: [list of feature IDs]
---
```

### Required Sections

1. **User Story**: As a {role}, I want {capability}, so that {benefit}
2. **Scope**:
   - **In scope**: what this feature delivers
   - **Out of scope**: what it explicitly does NOT deliver (prevents scope creep)
3. **User Flow**: step-by-step interaction from the user's perspective
4. **Acceptance Criteria**: testable conditions that must be true when done

### Recommended Sections

- **Non-functional requirements**: performance, security, accessibility
- **Edge cases**: unusual inputs, error states, boundary conditions
- **Dependencies**: other features, external services, infrastructure
- **Open questions**: unresolved decisions (must be resolved before implementation)

## Naming Conventions

- Feature IDs: `{PREFIX}-FEATURE-{N}` (sequential within the project)
- Epic IDs: `{PREFIX}-EPIC-{N}`
- Story IDs: `{PREFIX}-STORY-{N}`
- Content task IDs: `{PREFIX}-CTASK-{N}`

## Spec Quality Criteria

A spec is ready for implementation when:
- All acceptance criteria are testable (can write a pass/fail test for each)
- No open questions remain
- Dependencies are identified and either available or scheduled
- Scope boundaries are explicit (in-scope and out-of-scope defined)
- Edge cases are documented

# Backend Architecture

## Principles

- **Clean Architecture**: Domain → Application → Infrastructure. Dependencies point inward — Domain imports nothing external, Application imports only Domain, Infrastructure implements interfaces defined by inner layers.
- **CQRS**: Separate command (write) and query (read) paths when complexity warrants it. Write-side uses transactional database with strong consistency. Read-side can use optimized projections with eventual consistency.
- **Thin transport handlers**: Controllers/route handlers are pure orchestrators:
  1. **Parse** — extract and validate input from the request
  2. **Delegate** — call exactly one method on a business-layer service
  3. **Return** — format and return the response
  No business logic in handlers. No database queries. No conditional branching based on domain state.

## Module Structure

Organize code by bounded context / business domain, not by technical layer:

```
src/
├── {module-a}/
│   ├── domain/          # Entities, value objects, domain services, interfaces
│   ├── application/     # Command/query handlers, DTOs, application services
│   └── infrastructure/  # Repository implementations, external service clients
├── {module-b}/
│   ├── domain/
│   ├── application/
│   └── infrastructure/
└── shared/              # Cross-cutting: kernel, contracts, utilities
```

## Cross-Module Communication

Modules communicate through well-defined contracts, not direct imports:

- Consumer defines the interface it needs in its own domain/application layer
- Provider implements the interface in its infrastructure layer
- Shared contracts for external systems (storage, ID generation) belong in `shared/`
- Neither module imports the other's internals

## Event-Driven Patterns

For cross-module state synchronization:

1. **Receive** — consume the domain event
2. **Fetch** — load relevant data from the source
3. **Construct** — build the read model / projection
4. **Fan-out** — notify downstream consumers if needed
5. **Acknowledge** — confirm processing

## Entity Conventions

- Every entity has `createdAt` and `updatedAt` timestamps (UTC, ISO 8601)
- Use immutable date objects
- Entity creation through factory methods, not public constructors
- Value objects validate in constructors — invalid state cannot exist

## Repository Conventions

- Repositories return domain entities, not raw data
- Use explicit finder methods: `findById()`, `findByEmail()` — not generic `find(criteria)`
- Throw domain exceptions for "not found" cases, not null returns (unless optional)

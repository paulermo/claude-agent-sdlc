# API Standards

## Error Responses

All error responses use RFC 7807 Problem Details format (`application/problem+json`):

```json
{
  "type": "/errors/validation-failed",
  "title": "Validation Failed",
  "status": 422,
  "detail": "The 'email' field must be a valid email address.",
  "traceId": "abc-123-def"
}
```

- `type`: relative URI identifying the error type
- `title`: short human-readable summary
- `status`: HTTP status code (duplicated for convenience)
- `detail`: human-readable explanation specific to this occurrence
- `traceId`: request trace identifier for debugging

For validation errors with multiple fields:
```json
{
  "type": "/errors/validation-failed",
  "title": "Validation Failed",
  "status": 422,
  "detail": "One or more fields failed validation.",
  "violations": [
    { "field": "email", "message": "Must be a valid email address" },
    { "field": "name", "message": "Must not be empty" }
  ]
}
```

## Status Codes

| Code | When |
|------|------|
| 200 | Successful retrieval or update |
| 201 | Resource created |
| 204 | Successful deletion or action with no response body |
| 400 | Malformed request (invalid JSON, missing required fields) |
| 401 | Authentication required |
| 403 | Authenticated but not authorized |
| 404 | Resource not found |
| 409 | Conflict (duplicate, state conflict) |
| 422 | Validation failed (well-formed request, business rule violation) |
| 500 | Unexpected server error |

## Pagination

All collection endpoints use cursor-based pagination:

```
GET /resources?limit=20&after=cursor_abc
```

Response envelope:
```json
{
  "data": [...],
  "_metadata": {
    "hasMore": true,
    "cursor": "cursor_xyz"
  }
}
```

- No offset-based pagination (performance degrades at scale)
- Default page size: 20, maximum: 100
- Total count omitted by default (expensive query), opt-in if needed

## JSON Conventions

- **Property names**: `camelCase`
- **Date/time**: ISO 8601 with timezone (`2026-01-15T10:30:00Z`)
- **Enums in responses**: lowercase string values (`"active"`, `"pending"`)
- **Empty collections**: return `[]`, not `null`
- **Null fields**: omit from response rather than sending `null` (unless absence vs. null is meaningful)

## Action Endpoints

State transitions and toggles use verb-based action endpoints, not generic PATCH with a status field:

```
POST /resources/{id}/publish     — not PATCH /resources/{id} { "status": "published" }
POST /resources/{id}/archive
POST /resources/{id}/activate
```

If an operation has preconditions, triggers side effects, or changes lifecycle state, it must be its own endpoint.

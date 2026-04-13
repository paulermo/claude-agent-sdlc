# Docker Conventions

## Dockerfile Best Practices

- **Multi-stage builds** — separate build dependencies from runtime image
- **Minimal base images** — use `-slim` or `-alpine` variants
- **Pin versions** — never use `latest` tag for base images
- **Non-root user** — run application as non-root user
- **Health checks** — include `HEALTHCHECK` instruction
- **`.dockerignore`** — exclude build artifacts, tests, docs, `.git`
- **Layer ordering** — copy dependency files first (for caching), then source code

```dockerfile
# Example: multi-stage build
FROM node:20-slim AS builder
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM node:20-slim
WORKDIR /app
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
USER node
HEALTHCHECK --interval=30s --timeout=5s CMD curl -f http://localhost:3000/health || exit 1
CMD ["node", "dist/main.js"]
```

## Docker Compose

- **Shared infrastructure** (databases, caches, message brokers) in a base compose file
- **Service-specific overrides** in per-service compose files
- **Named volumes** for persistent data (databases, caches)
- **Health checks** on all services — dependent services use `depends_on: condition: service_healthy`
- **Environment variables** via `.env` file for local development (gitignored)
- **Network isolation** — services communicate over a shared bridge network

## Container Security

- Scan images for vulnerabilities in CI/CD (Trivy, Grype, etc.)
- Never store secrets in Docker images or build args
- Use read-only filesystem where possible (`--read-only`)
- Set resource limits (memory, CPU) in compose/K8s manifests

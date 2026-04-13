# Secrets Management

## Principles

- **Never store secrets in code** — no API keys, passwords, tokens in source files
- **Never commit secrets** — `.env` files, credential files, and terraform.tfvars are gitignored
- **Secrets belong in secret managers** — cloud-native (AWS Secrets Manager, GCP Secret Manager, Azure Key Vault) or self-hosted (Vault)

## Environment Variable Classification

### Non-sensitive (can be in code/config)
- Application ports, host names
- Feature flags (non-security)
- Log levels
- Public API endpoints (base URLs)
- Application mode (development, staging, production)

### Sensitive (must use secret manager)
- Database credentials
- API keys and tokens
- OAuth client secrets
- Encryption keys
- JWT signing keys
- Third-party service credentials

## Per-Environment Strategy

### Local Development
- Non-sensitive: inline in `docker-compose.yml` or `.env` (gitignored)
- Sensitive: `.env` file (gitignored) or local secret manager mock
- Template: provide `.env.example` with placeholder values (committed)

### Staging / Production
- Non-sensitive: environment config files or CI/CD variables
- Sensitive: cloud secret manager, injected at runtime
- Infrastructure: managed via Terraform/Pulumi (secret references, not values)
- Never store secret values in Terraform state — use data sources and references

## Anti-patterns

- Hardcoded credentials in source code
- Secrets in Docker build args or image layers
- Secrets in CI/CD environment variables (use CI/CD secret storage instead)
- Committing `.env` files
- Sharing secrets via chat, email, or tickets
- `terraform.tfvars` with secret values committed to git

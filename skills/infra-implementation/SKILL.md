---
name: infra-implementation
description: "The DevOps Engineer's discipline: implementing the cloud design — Dockerfiles, CI/CD, IaC, Kubernetes — with validation gates. Preloaded into the DevOps Engineer agent."
---

# Infra Implementation

You implement exactly what `.claude/rules/infra/cloud-architecture.md` designs. Design gaps go back to the Cloud Architect via your report — you don't fill them by improvising.

## Workflow: Assess → Design → Implement → Validate → Document

### 1. Assess
Read the cloud architecture, all `.claude/rules/infra/*.md`, `.claude/rules/quality-gate.md`, the app's runtime requirements (language/framework/deps from project config files), and existing infra files.

### 2. Design the implementation
CI/CD stages (build → test → scan → push → deploy), containerization strategy, IaC module layout, the deployment strategy the design prescribes.

### 3. Implement

| Artifact | Non-negotiables |
|----------|-----------------|
| Dockerfiles | multi-stage; non-root runtime user; HEALTHCHECK; pinned base versions (never `latest` outside dev); .dockerignore |
| CI/CD | build+test stages run the quality-gate commands; image scanning; IaC validation step; approval gate before production; artifacts versioned by git SHA or semver |
| IaC (Terraform/Pulumi) | modules mirroring the cloud design; env separation (dev/staging/prod var files); remote state with locking |
| Kubernetes (if applicable) | resource limits on every container; liveness/readiness/startup probes; ConfigMaps/Secret references (never values); HPA where the design scales |

### 4. Validate — actual outputs go in your report
- `terraform plan` / `pulumi preview` → no unexpected destroys.
- Lint: hadolint (Dockerfiles), tflint (Terraform), `kubectl apply --dry-run=client` (manifests) — use what's installed; name what wasn't available.
- Run the pipeline locally where possible (act, docker build, compose up).

### 5. Document
Write `.claude/rules/infra/devops.md`: pipeline overview, deployment procedure, rollback procedure, environment configuration guide. Update epic.md with implementation notes. Commit: `{PREFIX}-EPIC-{N}: Implement infrastructure for {feature} [by DevOps Engineer]`.

## Perspectives — check every decision through three hats
**Build**: fast, reliable, reproducible? **Deploy**: safe, reversible, observable? **Ops**: can the team monitor, debug, recover?

## Report

```
=== AGENT REPORT ===
AGENT: DevOps Engineer
ITEM: {EPIC-ID | project}
OUTCOME: IMPLEMENTED | NEEDS_DESIGN_FIX | BLOCKED
EVIDENCE:
- terraform plan / preview: {actual summary}
- lint results: {tool: result, or "not installed"}
- pipeline validated: {how}
FILES:
- {every artifact created/modified}
BLOCKERS: {none | list}
DETAILS: {NEEDS_DESIGN_FIX: the cloud-design gaps, quoted}
=== END REPORT ===
```

## MUST DO
IaC for ALL resources; health checks everywhere; secrets in secret managers only; scanning in CI; documented rollback; pinned versions; resource limits; deployment verification steps (smoke tests).

## MUST NOT DO
Production deploys without approval gates; secrets in code/env files/CI variables; `latest` tags outside dev; skipping staging; IaC without remote state+locking; manual changes bypassing IaC; "quick and dirty" pipelines; editing `docs/state/*.json`.

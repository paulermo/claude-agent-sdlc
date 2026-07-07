---
name: story-qa
description: "The QA discipline: standard E2E testing of stories and content, regression testing after merges, evidence rules, working-directory rules. Preloaded into the QA agent."
---

# Story QA

You prove behavior by executing it. Reading code is never QA. Your brief names the mode; the mode decides everything else.

| Mode | Trigger (in brief) | Where you work |
|------|--------------------|----------------|
| Standard | story/content task in `in_qa` | the item's worktree |
| Regression (story) | story `merged` to feature branch | the `{worktree_dir}/{EPIC-ID}-merge` worktree |
| Regression (epic) | epic `deployed` to main | the main working copy |

## Mode: Standard

1. Read the story's acceptance criteria and the use case's main / alternative / exception flows. Read `.claude/rules/quality-gate.md`.
2. **Run the application.** Use the worktree-specific ports from your brief to avoid collisions with parallel agents:
   `COMPOSE_PROJECT_NAME={item-id-lower} APP_PORT={app} DB_PORT={db} docker compose up -d` — or the project's dev-server command from quality-gate.md with `PORT={app}`.
   If the app won't start, that is your finding — OUTCOME: FAILED with the startup error, not a skipped test.
3. **Write E2E tests** with the project's E2E framework (from quality-gate.md; if the project has none, script the flows with what exists — curl for APIs, the test runner for integration flows). Coverage law: **every acceptance criterion → at least one E2E scenario**; every use-case exception flow → at least one negative test.
4. Execute all of it. Collect actual outputs.
5. If the item was previously `qa_rejected`: verify EVERY item of the prior feedback explicitly — list each as FIXED / STILL BROKEN in DETAILS.
6. For content tasks: verify presence (renders in the right place) and correctness (matches the approved content, no truncation/encoding damage). Classify any failure as `content` (the material is wrong) vs `integration` (the wiring is wrong) — the PM routes rework by this.
7. Commit your tests: `{ITEM-ID}: Add e2e tests for {feature} [by QA]`.

## Mode: Regression

WHY this mode exists: a clean merge can still break the whole — regressions hide in shared files.

1. Read `.claude/rules/quality-gate.md`. Run the FULL suite — all commands, not the story's subset.
2. Scan for merge artifacts: `git grep -nE '^(<<<<<<<|=======|>>>>>>>)' -- .` MUST return nothing.
3. Spot-check the 2-3 most critical acceptance criteria of the merged story (epic mode: one per story): the implementing code and its wiring survived the merge intact.
4. Epic mode additionally: cross-story checks — shared files (dependency manifests, schemas, barrel exports) contain BOTH sides' contributions; the full suite covers all epic stories.
5. You write nothing in regression mode except (optionally) a failing-test reproduction; never "fix" what you find — report it.

## Report

```
=== AGENT REPORT ===
AGENT: QA
ITEM: {ITEM-ID}
OUTCOME: PASSED | FAILED
EVIDENCE:
- mode: {standard | regression-story | regression-epic}
- app started: {yes/no + how}
- {each quality-gate command}: {actual result}
- AC coverage: {list: AC-1 → test name → pass/fail}
- merge-artifact scan: {clean | findings}        [regression only]
FILES:
- {test files created} | none
BLOCKERS: {none | list}
DETAILS: {per failure: exact reproduction steps, expected vs actual}
         {content tasks: rejection_reason: content | integration}
         {re-test: prior feedback items each FIXED / STILL BROKEN}
=== END REPORT ===
```

## Anti-rationalization table

| If you're thinking… | Reality |
|---------------------|---------|
| "The unit tests pass, E2E is redundant" | Unit tests don't catch wiring. Execute the flow. |
| "The code obviously implements the AC" | Reading is not testing. Run it. |
| "One flaky test, I'll ignore it" | Flaky = finding. Report it in DETAILS. |
| "Regression = re-run the story's tests" | Regression = FULL suite + spot-checks. The story's tests already passed once. |

## MUST DO
- Execute the application/flows for every verdict — evidence is outputs, not reading.
- Cover every acceptance criterion and every exception flow.
- Provide reproduction steps for every failure (a failure without steps is not actionable).

## MUST NOT DO
- Modify application source — test files and test configs only (regression: nothing).
- Edit `docs/state/*.json` — report; the PM writes state.
- Pass an item with skipped/flaky tests unmentioned, or with any prior-feedback item unverified.

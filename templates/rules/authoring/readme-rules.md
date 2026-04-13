# README.md Authoring Rules

## Purpose

`README.md` is for humans. It tells developers what this project is, how to get started, and where to find things.

**Boundary with CLAUDE.md:** README is for humans. CLAUDE.md is for Claude Code. Don't mix them.

## Required Sections

### 1. Title and Description
- Project name as H1
- One paragraph: what it does, who it's for

### 2. Where to Start (role routing table)

| Role | Start here |
|------|-----------|
| New developer | Getting Started |
| Reviewer | Architecture section |
| DevOps | Infrastructure section |

### 3. Project Structure
- Directory tree showing key directories
- One-line description per directory
- Don't list every file — show the shape

### 4. Getting Started
- Prerequisites (runtime, tools, accounts)
- Setup steps (clone, install, configure)
- Run commands (dev server, tests)
- Verify it works (expected output)

### 5. Contributing
- Branch naming convention
- Commit message format
- PR process
- Where to ask questions

## Writing Rules

- **Imperative mood** for instructions: "Run `npm install`", not "You should run..."
- **Concrete examples** over abstract explanations
- **Copy-paste ready** commands — no placeholder text without explanation
- **Keep it current** — stale README is worse than no README

## Update Triggers

Update when:
- New service or app is added
- Setup/install/run steps change
- A new role entry point is introduced
- Access URLs change
- Contributing conventions change

Skip for:
- Internal refactors
- Test-only changes
- Dependency bumps with no visible impact

---
name: "SDLC: Env"
description: "Configure project environments"
---

Configure project environments without launching the full SDLC pipeline.

**Steps:**

1. **Read current environments:**
   Read `docs/state/environments.json`. If it doesn't exist, output:
   > "SDLC not initialized. Run `/sdlc:init` first."
   and stop.

2. **Show current state:**
   Display each environment with its configuration status:
   ```
   Environments:
     dev       [not configured]  url: -
     staging   [configured]      url: https://staging.example.com
     prod      [not configured]  url: -
   ```

3. **Ask what to configure** using AskUserQuestion:
   > "Which environment to configure? Or 'add' to add a new environment."

4. **For existing environment — ask for details:**
   - URL (if not set)
   - Any other configuration needed
   - Update `environments.json`
   - Optionally update `.secrets.json` with credentials

5. **For new environment:**
   - Ask for name
   - Ask for URL
   - Add to `environments.json`

6. **Save and confirm:**
   Write updated `environments.json`. Do NOT commit automatically — the user may want to make more changes.

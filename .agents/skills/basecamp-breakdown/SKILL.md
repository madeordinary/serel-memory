---
name: basecamp-breakdown
description: "Break down a basecamp task before implementation in Codex. Use when the user asks to plan, break down work, assess scope, or decide how to proceed before editing."
---

# Basecamp Breakdown

Use this skill when the user wants a plan before execution. Do not edit files while planning.

## Workflow

1. Read the relevant memory-bank files for project intent:
   - `projectbrief.md`
   - `productContext.md`
   - `systemPatterns.md`
   - `techContext.md`
   - `decisionLog.md`
   - `activeContext.md`
   - `progress.md`
2. Read `.rules`.
3. Inspect only the files needed to make the plan concrete.
4. Produce the plan in this order:

```text
GOAL:
[one sentence - what success looks like]

SCOPE:
[specific files, components, or areas likely to change]

STEPS:
1. [verb + concrete action]
2. [verb + concrete action]
3. [verb + concrete action]

RISKS & UNKNOWNS:
- [risk, assumption, or validation gap]

OUT OF SCOPE:
- [what this plan will deliberately not do]
```

After producing the plan, get a second opinion from the other CLI before presenting to the user:

1. Build a concise prompt containing the plan and relevant context.
2. Shell out to the Claude CLI in read-only mode:

   ```bash
   claude -p --permission-mode plan "<prompt>"
   ```

   If `claude` is unavailable, perform a local self-critique instead — but say so.

3. Append a **Claude Review** section to the output with:
   - Agreements
   - Disagreements or gaps
   - Suggested changes worth adopting
   - Questions to resolve before proceeding

Then end with: **"Want me to proceed, or change something first?"** and wait.

## Rules

- Keep plans to 3-7 steps. If the work is larger, recommend splitting it.
- Say material assumptions explicitly.
- If the memory bank is blank, stale, or contradictory, say what is missing before guessing.
- Do not start implementation until the user confirms.

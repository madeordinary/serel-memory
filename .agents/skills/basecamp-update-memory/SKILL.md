---
name: basecamp-update-memory
description: "Refresh basecamp memory-bank files after a work session. Use when the user asks to update memory, preserve session context, refresh activeContext/progress, or capture new project learnings."
---

# Basecamp Update Memory

Use this skill to update the memory bank from the current session. Always show proposed diffs before writing.

## Workflow

1. Read every file in `memory-bank/` and `.rules`.
2. Review what changed this session: built, decided, learned, deferred, or discovered.
3. Propose updates, focusing on:
   - `memory-bank/activeContext.md` - current focus, recent changes, next steps, open questions
   - `memory-bank/progress.md` - what works, in progress, known issues, phase
4. Touch other files only if needed:
   - `systemPatterns.md` for real architectural decisions
   - `techContext.md` for dependencies, environment variables, runtime, or operational constraints
   - `decisionLog.md` for durable architectural, product, workflow, or operational decisions
   - `productContext.md` or `projectbrief.md` only if product intent changed
5. Append to `.rules` only for non-obvious reusable learnings.

For each proposed change, show:

```text
FILE: [path]
CHANGE: [add / update / remove]
DIFF:
[actual before/after for the affected section]
```

Wait for confirmation before writing.

## Rules

- Do not bloat the bank.
- Do not journal one-off events.
- If `.rules` already covers a learning, refine the existing entry instead of duplicating it.
- Keep `activeContext.md` current rather than preserving old session history.
- Promote information according to `docs/workflow-contract.md`: session state to `activeContext.md`, completed status to `progress.md`, durable decisions to `decisionLog.md`, reusable gotchas to `.rules`.

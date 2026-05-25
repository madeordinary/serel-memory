---
name: start
description: "Start or resume a memory-bank project in Codex. Use when the user asks to start, orient, summarize project state, load the memory bank, or decide where to pick up."
---

# Start

Use this skill to orient a Codex session around the basecamp memory bank.

## Workflow

1. Read every file in `memory-bank/` in this order:
   - `projectbrief.md`
   - `productContext.md`
   - `systemPatterns.md`
   - `techContext.md`
   - `decisionLog.md`
   - `activeContext.md`
   - `progress.md`
2. Read `.rules`.
3. Look for optional docs under `memory-bank/` that clearly match the user's task or active context, and read only the relevant ones.
4. Run `git log --oneline -10`.
5. Run `git status`.
6. Produce a context audit:

```text
CONTEXT AUDIT:
- Read: [memory-bank files and .rules]
- Optional docs read: [paths or "(none)"]
- Uninitialized: [missing, empty, or template-only files]
- Recent commits not reflected in memory: [yes/no/unknown]
- Working tree: [clean / dirty summary]
```

7. Produce this summary:

```text
PROJECT: [one sentence - what we're building]
PHASE: [from progress.md]
LAST SESSION: [from activeContext.md - what was being worked on]
CURRENT STATE: [what works / what's in progress / known issues - 2 lines max]
NEXT STEPS: [from activeContext.md - top 1-3]
OPEN QUESTIONS: [anything blocking or unresolved]
```

End with: **"Where do you want to pick up?"** Then wait.

If any memory bank file is missing, empty, or still only template placeholders, mark it as `BLANK` or `UNINITIALIZED` and ask whether to initialize it before proceeding.

---
description: Read the memory bank, summarize state, ask where to pick up
---

# /start

You are starting a new session on this project. Your memory has reset; the memory bank is your only continuity.

Do these in order, before anything else:

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
4. Run `git log --oneline -10` to see recent activity.
5. Run `git status` to see uncommitted changes.

Then produce a context audit and session summary in this exact format:

```
CONTEXT AUDIT:
- Read: [memory-bank files and .rules]
- Optional docs read: [paths or "(none)"]
- Uninitialized: [missing, empty, or template-only files]
- Recent commits not reflected in memory: [yes/no/unknown]
- Working tree: [clean / dirty summary]

PROJECT: [one sentence — what we're building]
PHASE: [from progress.md]
LAST SESSION: [from activeContext.md — what was being worked on]
CURRENT STATE: [what works / what's in progress / known issues — 2 lines max]
NEXT STEPS: [from activeContext.md — top 1–3]
OPEN QUESTIONS: [anything blocking or unresolved]
```

End with: **"Where do you want to pick up?"** Then wait.

Do not start working on anything until the user answers.

If any memory bank file is empty, missing, or still only template placeholders, surface it in the summary as `BLANK` or `UNINITIALIZED` and ask the user whether to initialize it before proceeding.

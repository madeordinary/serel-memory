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
   - `activeContext.md`
   - `progress.md`
2. Read `.rules`.
3. Run `git log --oneline -10` to see recent activity.
4. Run `git status` to see uncommitted changes.

Then produce a session summary in this exact format:

```
PROJECT: [one sentence — what we're building]
PHASE: [from progress.md]
LAST SESSION: [from activeContext.md — what was being worked on]
CURRENT STATE: [what works / what's in progress / known issues — 2 lines max]
NEXT STEPS: [from activeContext.md — top 1–3]
OPEN QUESTIONS: [anything blocking or unresolved]
```

End with: **"Where do you want to pick up?"** Then wait.

Do not start working on anything until the user answers.

If any memory bank file is empty or missing, surface it in the summary as `BLANK` and ask the user whether to initialize it before proceeding.

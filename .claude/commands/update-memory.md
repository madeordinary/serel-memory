---
description: Refresh the memory bank from this session's work
---

# /update-memory

Update the memory bank to reflect the work done this session. Show diffs before writing anything.

Steps:

1. Read every file in `memory-bank/` and `.rules`.
2. Review what changed in this session — what was built, decided, learned, deferred.
3. Propose updates. Focus especially on:
   - **`activeContext.md`** — refresh current focus, recent changes (top of list), next steps, open questions.
   - **`progress.md`** — move items from "in progress" to "what works"; add new known issues; update phase if it changed.
4. Touch other files only if they need it:
   - `systemPatterns.md` — only if a real architectural decision was made
   - `techContext.md` — only if dependencies, env vars, or runtime changed
   - `decisionLog.md` — only if a durable architectural, product, workflow, or operational decision was made. If a past decision changed, **supersede, don't delete**: append "SUPERSEDED by … (date)" and move it to the Superseded section.
   - `productContext.md` / `projectbrief.md` — only if the goal or user model actually shifted
5. Append to `.rules` any non-obvious thing learned this session: a user preference, a gotcha, a rejected approach worth remembering. Then **prune `.rules`**: if it's over ~40 lines or holds stale/obsolete lines, drop what's no longer true and promote stabilized conventions into `systemPatterns.md`. Keep it high-signal, not append-forever.

For each proposed change, show:

```
FILE: [path]
CHANGE: [add / update / remove]
DIFF:
[show the actual before/after for the affected section]
```

Wait for confirmation before writing any file. If the user pushes back, revise — don't argue.

Rules:

- Don't bloat. Every line in the bank should still be earning its place.
- Don't journal — this isn't a log. Old `activeContext.md` entries don't need to be preserved.
- If `.rules` already covers a learning, refine the existing entry instead of duplicating.
- Follow `docs/workflow-contract.md` when present: session state goes to `activeContext.md`, completed status to `progress.md`, durable decisions to `decisionLog.md`, reusable gotchas to `.rules`.

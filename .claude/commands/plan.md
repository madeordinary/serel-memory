---
description: Break a task into steps before executing
---

# /plan

For the task the user just described, do NOT take any action yet. Produce a plan first.

The plan must contain, in this order:

1. **Goal** — one sentence; what success looks like.
2. **Scope** — which files, components, or areas you'll touch. Be specific (paths, function names).
3. **Steps** — 3–7 concrete steps, each a single verb (add, refactor, test, document, deploy).
4. **Risks & unknowns** — what could go wrong, what you'd need to verify first, what assumptions you're making.
5. **Out of scope** — things you'll deliberately NOT do, in case the user wants them too.

After producing the plan, end with: **"Want me to proceed, or change something first?"**

Then wait. Do not start executing until the user confirms.

Rules:

- If the plan is longer than 7 steps, the task is too big — recommend splitting it.
- If you have to assume something material, say so explicitly. Don't bury assumptions inside step descriptions.
- If the memory bank doesn't have enough context for the plan, say what's missing and ask before guessing.

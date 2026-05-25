---
description: Break a task into steps before executing
---

# /breakdown

For the task the user just described, do NOT take any action yet. Produce a plan first.

The plan must contain, in this order:

1. **Goal** — one sentence; what success looks like.
2. **Scope** — which files, components, or areas you'll touch. Be specific (paths, function names).
3. **Steps** — 3–7 concrete steps, each a single verb (add, refactor, test, document, deploy).
4. **Risks & unknowns** — what could go wrong, what you'd need to verify first, what assumptions you're making.
5. **Out of scope** — things you'll deliberately NOT do, in case the user wants them too.

## Cross-agent review (mandatory)

After producing the plan, get a Codex second opinion before presenting to the user. Do not skip this step.

1. Verify Codex is available: `codex --version`
2. Build a concise prompt with the plan, the goal, and enough project context for a meaningful review.
3. Run Codex in read-only mode:

   ```bash
   codex exec --cd "$PWD" --sandbox read-only "<prompt>"
   ```

4. Append a **Second Opinion (Codex)** section to the plan output:
   - Agreements
   - Disagreements or gaps
   - Suggested changes worth adopting
   - Questions to resolve before proceeding

If `codex` is not installed or not authenticated, say so and perform a local self-critique instead. Label it **Self-Critique (Codex unavailable)** so the user knows no independent review happened.

Then end with: **"Want me to proceed, or change something first?"**

Wait. Do not start executing until the user confirms.

Rules:

- If the plan is longer than 7 steps, the task is too big — recommend splitting it.
- If you have to assume something material, say so explicitly. Don't bury assumptions inside step descriptions.
- If the memory bank, including `decisionLog.md`, doesn't have enough context for the plan, say what's missing and ask before guessing.

---
name: risk-review
description: "Surface project risks not yet captured in the memory bank. Use when the user asks for risk review, hidden risks, assumptions, unknowns, or pre-planning risk assessment."
---

# Risk Review

Surface risks and unknowns that aren't already captured in the memory bank. The goal is to find what could derail this project that nobody's named yet. Do not invent risks just to fill categories.

**Effective bank:** if `memory-bank.local/` exists (upstream Serel Memory development only), all memory-bank and `.rules` reads and writes below target it instead of the tracked templates; skip files it doesn't contain. See "Resolving the effective bank" in `docs/workflow-contract.md`.

**Scope:** resolve which bank this targets per "Resolving scope" in `docs/workflow-contract.md` — an optional `--scope <path>` argument selects a project bank when the repo configures `scopes`; otherwise the root bank, as always.

## Workflow

1. Read:
   - `memory-bank/projectbrief.md` — goals and success criteria
   - `memory-bank/productContext.md` — user/UX context
   - `memory-bank/systemPatterns.md` — architectural decisions and assumptions
   - `memory-bank/techContext.md` — stack, dependencies, constraints
   - `memory-bank/decisionLog.md` — durable decisions and ADR references
   - `memory-bank/activeContext.md` — current focus
   - `memory-bank/progress.md` — status and known issues
   - `.rules` — any documented gotchas or rejected approaches
2. Inspect relevant code, docs, dependency manifests, recent commits, or open diffs when needed.
3. Identify risks across these categories:
   - **Technical**: dependencies, scaling, architecture decisions that might not survive contact with reality
   - **Schedule**: dates, milestones, anything time-bound
   - **External/vendor**: vendors, APIs, integrations, anything outside the team's control
   - **Resource/capacity**: people, budget, capacity
   - **Scope**: ambiguity in requirements, scope creep, feature inflation
   - **Operational/security**: deployment, monitoring, on-call coverage, security
   - **Assumptions**: things the project assumes are true that might not be
4. Rank by likelihood times impact, highest combined likelihood × impact first.

## Output

For each risk:

```text
## [Short name]
- Category: [from above]
- What could go wrong: [specific failure mode]
- Likelihood: high / medium / low
- Impact if it hits: [concrete consequence]
- Mitigation: [what we could do now to reduce likelihood or impact]
- Status: undocumented / partially documented / documented but stale
```

Output a ranked list, highest combined likelihood × impact first.

## Rules

- Surface NEW risks. Don't just restate what's already in `progress.md` under "known issues."
- Be specific. "API might be slow" is not a risk; "Vendor X's rate limit is 100 req/min and we're projecting 300 req/min at launch" is.
- Don't manufacture risks. If a category has nothing real, say so explicitly.
- If a risk is genuinely "out of our control," still name it — visibility matters even when action doesn't.

After the review, ask the user which risks belong in `memory-bank/activeContext.md`, `memory-bank/progress.md`, or `memory-bank/decisionLog.md`, and add them with confirmation. Do not write memory updates without confirmation.

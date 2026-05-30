---
description: Review the current branch or uncommitted diff
---

# /review

Review the code currently on this branch (or the uncommitted diff if there's nothing branch-specific). You are a thorough but constructive senior reviewer — your goal is to help the change ship better, not to gatekeep. Take a read-only stance: **do not edit files** during a review.

Steps:

1. Read relevant project context: `memory-bank/projectbrief.md`, `systemPatterns.md`, `techContext.md`, `decisionLog.md`, `activeContext.md`, and `.rules`.
2. Run `git diff main...HEAD` (or `git diff` for uncommitted changes) to see what changed. If `main` doesn't exist, find the likely base branch or state the fallback.
3. Read modified files in full when context matters — not just the diff.
4. Check the change against the memory bank: does it match `projectbrief.md` goals, `systemPatterns.md` architecture, and `decisionLog.md` decisions?

Then produce findings in this exact format:

```
SUMMARY: [one sentence — what this change does and your overall take]

HIGH (must fix before merge):
- [file:line] [issue] → [suggested fix]

MEDIUM (should fix before merge):
- [file:line] [issue] → [suggested fix]

LOW (nice to have):
- [file:line] [issue] → [suggested fix]

QUESTIONS:
- [anything you couldn't determine from the code]
```

At minimum, check for:

- **Correctness** — does it do what the diff/commit claims?
- **Tests** — do tests exist for new behavior; are edge cases covered?
- **Naming & clarity** — are names accurate; could a new reader follow this?
- **Error handling** — are failure paths handled or documented?
- **Side effects** — unintended changes, leftover `console.log` / debug prints?
- **Security** — input validation, secrets in code, auth bypasses?
- **Performance** — obvious O(n²), N+1, or unbounded growth?

Always include a SUMMARY line, even if there are no HIGH findings. If everything looks good, say so clearly — false positives waste trust.

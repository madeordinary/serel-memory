---
name: basecamp-review
description: "Review the current branch, diff, or proposed change in Codex. Use when the user asks for a code review, branch review, diff review, or quality/risk pass."
---

# Basecamp Review

Use this skill to review code or a proposed change. Take a code-review stance: findings first, grounded in file and line references when possible. Do not edit files.

## Workflow

1. Read relevant project context:
   - `memory-bank/projectbrief.md`
   - `memory-bank/systemPatterns.md`
   - `memory-bank/techContext.md`
   - `memory-bank/decisionLog.md`
   - `memory-bank/activeContext.md`
   - `.rules`
2. Inspect the change:
   - Prefer `git diff main...HEAD` for branch changes.
   - Use `git diff` for uncommitted changes.
   - If `main` does not exist, find the likely base branch or state the fallback.
3. Read modified files in full when the diff alone is not enough.
4. Check at minimum:
   - Correctness and edge cases
   - Tests for new behavior
   - Naming and clarity
   - Error handling
   - Side effects and leftover debug code
   - Security and secret leakage
   - Performance pitfalls
   - Alignment with memory-bank intent and decisions

## Output

```text
SUMMARY: [one sentence - what changed and overall take]

HIGH (must fix before merge):
- [file:line] [issue] -> [suggested fix]

MEDIUM (should fix before merge):
- [file:line] [issue] -> [suggested fix]

LOW (nice to have):
- [file:line] [issue] -> [suggested fix]

QUESTIONS:
- [anything you could not determine from code]
```

If there are no findings, say so clearly and mention any remaining test gaps or residual risk.

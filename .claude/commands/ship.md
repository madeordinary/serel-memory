---
description: "Run a pre-merge ship readiness checklist. Use when the user asks whether a branch/change is ready to merge, ship, release, or needs final checks."
---

# /ship

You're being asked whether the current branch is ready to merge. Run through the checklist and produce a clear ship/don't-ship recommendation.

**Scope:** resolve which bank this targets per "Resolving scope" in `docs/workflow-contract.md` — an optional `--scope <path>` argument selects a project bank when the repo configures `scopes`; otherwise the root bank, as always.

Checklist:

1. **Tests pass.** Run the test suite. If there are no tests for a project that should have them, flag it.
2. **New behavior has tests.** Look at the diff — anything new without a corresponding test?
3. **Documentation updated.** README, docs/, comments on non-obvious code, anywhere users would look.
4. **Env vars documented.** If new env vars were added, are they in README and/or `.env.example`?
5. **CHANGELOG updated.** If the project has one, does this change appear in it?
6. **Memory bank updated.** Does `progress.md` reflect what changed? Is `activeContext.md` current? Does `decisionLog.md` reflect any durable decisions?
7. **No leftover debug code.** Search for `console.log`, `print(`, `debugger`, TODOs without a tracking link, commented-out blocks.
8. **No secrets leaked.** Scan diff for API keys, tokens, passwords, internal URLs.
9. **Commit history is reasonable.** Either clean commits or a sensible squash plan.
10. **Behavior proven.** For each behavior change in the diff, give the evidence you observed this session and how you got it (see below).

Output format:

```text
SHIP READINESS: [READY / NOT READY / READY WITH CAVEATS]

CHECKLIST:
[✓ or ✗] 1. Tests pass — [detail]
[✓ or ✗] 2. New behavior has tests — [detail]
[✓ or ✗] 3. Documentation updated — [detail]
[✓ or ✗] 4. Env vars documented — [detail]
[✓ or ✗] 5. CHANGELOG updated — [detail]
[✓ or ✗] 6. Memory bank updated — [detail]
[✓ or ✗] 7. No leftover debug code — [detail]
[✓ or ✗] 8. No secrets leaked — [detail]
[✓ or ✗] 9. Commit history reasonable — [detail]
[✓ or ✗] 10. Behavior proven — [per change: what you observed and how, or unproven]

BLOCKERS (must fix):
- 

CAVEATS (should fix but not blocking):
- 

RECOMMENDATION: [one sentence]
```

**Behavior proven** means evidence you observed this session: command output, a reproduction that failed before the change and passes after, the app run and the change looked at, or a screenshot. Mocked or unit tests alone don't prove user-facing behavior. If a changed feature has a verification map at `<effective bank>/verification/<feature>.md` (written by Serel Kit's optional verify pack; see "Resolving the effective bank" in `docs/workflow-contract.md`), follow its Recipe and report the date of its newest record, or that it has none — an older record doesn't prove this change. Read the map only when it exists, and never write it.

**Verdict:** any blocker means NOT READY — failing tests stay NOT READY however well the rest is proven. Otherwise, never report READY while a behavior change is unproven: say READY WITH CAVEATS and list each unproven change under CAVEATS.

If something is ambiguous, ask before declaring NOT READY — don't fail someone on something you misread.

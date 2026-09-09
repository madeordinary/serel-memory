# 001. Scoped memory banks: one bank per initiative, opt-in, one scope per invocation

## Status

Accepted (2026-09-09)

## Context

Serel Memory assumed one repo = one `memory-bank/` at the root. That fits a
single codebase. It does not fit a workspace that hosts several concurrent,
independently paced initiatives — a portfolio or product-management repo where
"what is the state of A" and "what is the state of B" collapse into one
`activeContext.md`, or are forced into separate repos with no single place to
land. Real downstream usage produced a working local pilot of per-project banks
and showed the framework's two existing notions of "effective bank" (the
maintainer overlay and per-project scope) did not compose.

## Decision

- **Opt-in by configuration, never by convention.** `.serel-memory.json` may
  carry `"scopes": [<parent folders>]`. Every immediate child of a scope root
  is a project root with its own standard seven-file bank and `.rules`. Without
  `scopes`, behavior is unchanged.
- **One rule, resolved explicitly on every invocation:** `--scope <path>`
  (`.` = root; unknown paths stop and list valid selectors), else the current
  directory, else the root. Nothing persists a previous selection. Paths, not
  bare names.
- **One bank read, one bank written per invocation.** The only exception is
  enumeration at the root: project selectors and an initialized marker, never
  project bank content.
- **The maintainer overlay applies inside the selected scope.** Writes go to
  the scope's own `.rules` (the overlay's when selected, even if absent);
  reads fall back to the scope's plain `.rules`; project scopes additionally
  read the repo's effective `.rules` as inherited guidance.
- **One implementation.** `hooks/lib/resolve-scope.sh` is the executable rule
  for hooks and tests; prompts describe the same rule and point at the
  contract. `sync-upstream` is repo-root anchored regardless of scope.
- **Degrade to single-bank, never guess.** Malformed or overlapping `scopes`,
  or a missing `jq`, disable scopes with one warning.

## Alternatives considered

- **Detect projects by fixed folder names** (`projects/running/...`): rejected —
  bakes one workspace's layout into the framework and changes behavior for
  repos that happen to use those names.
- **Remember the scope `/start` selected for the rest of the session**: rejected
  — hooks cannot see it, so `/update-memory` and PreCompact could target a
  different bank than the user expects.
- **Read one summary sentence from each project bank at the root**: rejected
  for now — it breaks the one-bank rule and grows with N; selectors and an
  initialized marker are enough to choose.
- **Separate multi-repo machinery**: out of scope; this is intra-repo scoping.

## Consequences

**Positive**

- Bank format is unchanged; a project moves between scope roots as a folder
  move.
- Non-code workspaces fit without a new file shape (`systemPatterns` = how the
  work gets done, `techContext` = tools and data sources).
- Staleness detection (the planned deterministic checker) gains a natural path
  argument.

**Negative**

- Every workflow prompt carries a scope pointer; `/start` and
  `/update-memory` carry a little more text.
- `jq` becomes required to *use* scopes (not to use Serel Memory).

**Neutral**

- Retention and archives apply per bank.

## References

- `docs/workflow-contract.md` — "Resolving scope"
- `hooks/lib/resolve-scope.sh`, `tests/smoke-scopes.sh`
- `CHANGELOG.md` — Unreleased

# 002. A deterministic drift checker that refuses to grade meaning

## Status

Accepted (2026-09-09)

## Context

The memory bank is written by the same agent that later relies on it, and
nothing checks it. A line like "the queue drains" stays in `## What works`
long after the queue was deleted, and every session that reads it inherits the
mistake with full confidence. `/start` already asks the agent to flag
staleness, but an LLM judging its own prose is the weakest possible check:
non-reproducible, unfalsifiable, and most confident exactly where it is wrong.

The parts that *are* mechanically decidable were going unchecked: whether the
anchor parses, whether the seven core files exist, whether a file is still the
shipped template, whether the file a bank line points at has changed since the
commit that line named.

## Decision

Ship `bin/serel-memory check` — pure Bash, git, and `jq`, read-only, offline —
and give it a narrow, honest remit.

- **It decides only what the repo can settle.** Anchor shape, bank presence and
  initialization, retention targets, evidence markers, and a bounded framework
  baseline. Everything else is out of scope by construction.
- **It refuses to decide meaning.** No line is ever reported as true or false.
  A `verified: <sha> <path>...` marker is compared, not believed: the checker
  says the declared evidence is unchanged or differs since that sha. Bullets
  without a marker are *counted, not judged*, and the count is printed — the
  visible measure of what the check does not cover.
- **Not-assessed is louder than bad.** Any `INCOMPLETE` exits 2, above the 1
  for real `DRIFT` or `STALE`. A checker that cannot see must never look clean.
- **Offline-first.** No fetch, ever. The framework baseline runs only when the
  anchor's `ref` already resolves locally (`sync-upstream` leaves it in
  `refs/serel-memory/anchor`); otherwise the summary says `baseline:
  unavailable` rather than silently skipping a check.
- **One scope per invocation**, resolved by the existing
  `hooks/lib/resolve-scope.sh` called as a subprocess — the resolver stays the
  single implementation of that rule.

## Alternatives considered

- **An LLM-graded bank audit**: rejected as the primary mechanism — a model
  grading its own memory is not evidence. The offered cross-agent audit in
  `/update-memory` stays as the *semantic* complement; this checker is the
  deterministic floor beneath it.
- **Timestamp-based staleness** ("activeContext untouched for 30 days"):
  rejected — measures typing, not truth. A correct bank that nobody edited is
  not stale.
- **Diff the whole repo against the bank's claims**: rejected — no bounded,
  reproducible mapping exists from a sentence to a file set. Markers make the
  mapping explicit and author-declared, which is the only version a machine can
  check.
- **Fetch upstream to compare framework files**: rejected — a check that needs
  the network fails differently on every machine, and `/start` must stay fast
  and offline. `sync-upstream` owns the network.
- **Warn on unmarked bullets**: rejected — most banks have no markers today, so
  this would produce noise that trains people to ignore the checker. They are
  counted instead.

## Consequences

**Positive**

- `/start` and `/update-memory` can state bank health in one reproducible line
  instead of an impression.
- Markers give the framework a way to record *what a claim rests on*, and CI
  or a hook can gate on the exit code.
- The seven shipped templates are detected as uninitialized, so a fresh install
  is told to seed the bank rather than trusting empty scaffolding.

**Negative**

- Another executable in a framework that was pure Markdown; it must stay
  shellcheck-clean and portable (BSD and GNU userland).
- `jq` moves from "required for scopes" to "required for `check`". Serel Memory
  itself still needs neither.
- Template-only detection is heuristic. It is deliberately conservative — one
  real line makes a file initialized — and `tests/smoke-check.sh` pins it
  against all seven shipped templates so it cannot rot silently.

**Neutral**

- Markers are optional and additive; a bank with none is simply reported as
  fully unmarked.
- `--upstream` (compare against a fetched upstream) is deliberately deferred;
  the network belongs to `sync-upstream`.

## References

- `bin/serel-memory`, `tests/smoke-check.sh`
- `docs/workflow-contract.md` — "Drift check"
- [001. Scoped memory banks](001-scoped-memory-banks.md) — the resolver this
  checker calls, and the path argument it anticipated

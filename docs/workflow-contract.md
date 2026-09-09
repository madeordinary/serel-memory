# Workflow Contract

Serel Memory workflows should be small, explicit, and portable across agents. Use this
contract when adding or revising a Claude command, Codex skill, or future adapter.

## Required sections

Every workflow should make these things clear:

- **Trigger**: when to use it and when not to use it.
- **Required reads**: files, diffs, logs, or docs the agent must inspect first.
- **Allowed writes**: files the workflow may edit, and whether confirmation is required.
- **Output contract**: the exact shape users should expect back.
- **Stop conditions**: when the agent must pause for user input instead of guessing.

## Resolving the effective bank

Every reference to "the memory bank" or `.rules` in a workflow means the
**effective bank**:

- If `memory-bank.local/` exists (upstream Serel Memory development only — it is
  gitignored and never ships), it is the effective bank: read and write its
  files instead of the tracked `memory-bank/`, and `memory-bank.local/.rules`
  instead of root `.rules`. It is partial by design; for core files it lacks,
  `README.md` and `docs/` carry intent — don't flag the blank tracked
  templates as uninitialized, and never write maintainer state to them.
- Otherwise (every downstream project), the effective bank is `memory-bank/`
  and root `.rules`.

## Defaults

- Read `AGENTS.md`, the relevant memory-bank files, `.rules`, and recent git history when project intent matters.
- Treat code as source of truth for current behavior.
- Treat the memory bank as source of truth for intended behavior once initialized.
- Show diffs before writing memory-bank files.
- Ask before changing product scope, architecture, dependencies, security posture, or public behavior.
- Prefer one focused workflow over a broad persona.
- Read optional `memory-bank/` docs only when the current task clearly touches that topic.

## Optional memory docs

Keep the core memory bank small. When a topic outgrows the core files, add focused
optional docs under `memory-bank/`, for example:

- `memory-bank/features/<feature>.md`
- `memory-bank/integrations/<service>.md`
- `memory-bank/ops/<runbook-context>.md`
- `memory-bank/testing.md`

Optional docs are not part of the required startup read. Agents should find and
read them only when relevant to the task.

## Memory writes

Use this promotion path:

1. Current task details go in the conversation or temporary plan.
2. Current session state goes in `memory-bank/activeContext.md`.
3. Completed status goes in `memory-bank/progress.md`.
4. Durable decisions go in `memory-bank/decisionLog.md` and, when useful, `docs/decisions/`.
5. Reusable patterns and gotchas go in `.rules`.
6. Stable architecture goes in `memory-bank/systemPatterns.md`.

Do not turn the memory bank into a journal. A line should survive because it helps
the next session make a better decision.

## Retention

Bank files are read every session, so their size is the framework's context
budget. Retention keeps the two volatile files bounded without losing history.

**Soft targets, per effective bank:**

- `activeContext.md`: at most 200 lines and 12,000 bytes.
- `progress.md`: `## Recent milestones` keeps its 10 newest entries.
- `.rules`: about 40 lines (existing rule; pruned, not rotated).

**Protected sections are never rotated** — they are current state, rewritten
in place by the normal update:

- activeContext: `## Current focus`, `## Checkpoint`, `## Next steps`,
  `## Open questions`, `## Notes for next session`. Move a note into
  `Recent changes` once it is done; age alone does not make it history.
- progress: `## Status`, `## What works`, `## In progress`,
  `## What's left to build`, `## Known issues`.

**Rotatable units**, oldest first (banks are newest-first, so oldest is last):

- activeContext: an entire `## Recent changes (<suffix>)` section — the
  heading travels with its body — or a top-level bullet (a line starting
  with `-`) with its continuation lines under an unsuffixed `## Recent changes`.
- progress: a top-level bullet under `## Recent milestones`.
- Any other structure is left untouched and reported as remaining overage.

**Rotation is lossless.** Selected units move verbatim to
`<effective bank>/archive/<file>-<YYYY-MM>.md` (append, or create with a
one-line header), and the live file keeps one pointer line,
`Older entries: archive/<file>-*.md`, directly under the first
`## Recent ...` heading. If protected content alone exceeds the target,
report it and rotate nothing further — never truncate current state.
Rotating again with nothing rotatable is a no-op.

**Mechanism.** `hooks/lib/rotate-check.sh <file> <activeContext|progress>`
is read-only: it measures a file, lists rotatable units as line ranges,
predicts the result of rotating the fewest oldest units that meet the
target, and ends with `RESULT: NO-OP`, `RESULT: ROTATE n`, or
`RESULT: OVERAGE-REMAINS`. `/update-memory` and `$update-memory` must run it
on the *proposed* files, fold any `ROTATE n` into the same confirmation as
the content diffs, and re-run it after writing. The approval gate is
unchanged — the helper selects, the user approves, the agent writes.

**Archives are not routine reads.** `archive/` is excluded from the session
read list, `/start`, `/update-memory`, `/handoff`, and both hooks. Read an
archive only when the task needs that history.

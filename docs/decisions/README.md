# Decision records (ADRs)

This directory holds Architecture Decision Records — one file per durable decision,
capturing the context, the decision, the alternatives, and the consequences.

- Use `/decision-log` (Claude Code) or `$decision-log` (Codex) to draft one.
- Number them sequentially: `001-<slug>.md`, `002-<slug>.md`, …
- Add a one-line entry to `memory-bank/decisionLog.md`'s ADR index so future sessions
  can find it.
- **Supersede, don't delete.** When a decision changes, set the old ADR's status to
  `Superseded by NNN` rather than removing it.

Start from [`000-template.md`](000-template.md).

> This directory is project-owned. `sync-upstream` never touches it.

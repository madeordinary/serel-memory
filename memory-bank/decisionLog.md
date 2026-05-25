# Decision Log

> Durable decisions and why they were made. Use this for decisions future agents
> should not re-litigate without a good reason.
> Update when an architectural, product, workflow, or operational decision is made,
> superseded, or rejected.

## Active decisions

- **Mandatory cross-agent planning review**: Any non-trivial plan (3+ steps or multi-file) must get a second opinion from the other CLI before implementation. Baked into `/breakdown` and `$breakdown` automatically; AGENTS.md ground rule covers ad-hoc plans. Rationale: catches blind spots, missed risks, and simpler alternatives before committing to an approach.
- **Bare skill names over prefixed**: Codex skills use `$start`, `$review`, etc. instead of prefixed names. Rationale: slash commands already use bare names; these are core workflows, not a plugin. Collision risk for downstream projects is accepted — documented in README.
- **Asymmetric cross-agent naming**: `/ask-codex` (Claude command) maps to `$ask-claude` (Codex skill). Each names the *other* agent it calls. This is the one intentional parity exception — they are the same workflow, just inverted.
- **Explicit framework file allowlist for sync**: Sync-upstream uses a strict allowlist (`docs/workflow-contract.md`, `docs/cross-agent-review.md`) instead of blanket `docs/`. Rationale: README tells users to put PRDs and decisions under `docs/`, so syncing all of `docs/` would overwrite project material.
- **Two sync modes (fork vs template)**: Sync-upstream detects whether a merge base exists. Fork mode uses three-dot diffs; template mode (degit installs) requires user review for every change. Rationale: the primary install path (`npx degit`) creates unrelated git history.

## ADR index

<!-- Example: - [001. Use Postgres for state](../docs/decisions/001-use-postgres-for-state.md) - Accepted -->

-

## Superseded or deprecated

<!-- Decisions that are no longer true, with replacement if any. -->

-

## Decision criteria

<!-- Reusable principles that shape future decisions. -->

-

# Changelog

All notable changes to basecamp are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project aims to
follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html) once it reaches 1.0.

## [Unreleased]

### Added

- `.basecamp.json` provenance anchor: installs are now pinned and record the upstream
  version they started from; `sync-upstream` reads the anchor for precise
  what-changed-upstream reports, reconstructs a `"linked": true` anchor when missing,
  and advances it after a sync. The allowlist test now also guarantees the anchor is
  never in sync scope.
- "What makes it different" section in the README.
- Markdown lint (`markdownlint-cli2`) and link check (`lychee`) in CI; repo-wide
  markdown cleanup to zero lint errors.

## [0.1.0] — 2026-05-30

First tagged release. Pin to it with `npx degit gusfeliciano/basecamp#v0.1.0`.

### Added

- Memory-bank pattern: seven core templates (`projectbrief`, `productContext`,
  `systemPatterns`, `techContext`, `decisionLog`, `activeContext`, `progress`) plus a
  `.rules` learning journal, read at the start of every session.
- 17 workflows with full Claude Code + Codex parity (`start`, `discover`, `from-prd`,
  `init-memory`, `breakdown`, `review`, `update-memory`, `weekly-update`, `retro`,
  `risk-review`, `decision-log`, `handoff`, `ship`, `ask-codex`/`ask-claude`,
  `sync-upstream`, `runbook`, `security-check`).
- Optional, off-by-default hooks: `session-start` (auto-load the bank) and
  `pre-compact` (remind the agent to refresh the bank before Claude Code compacts).
- Cross-agent review: shell out to the other CLI for a read-only second opinion.
- `sync-upstream` for pulling framework updates into downstream projects.
- Framework-integrity tests (`tests/check-parity.sh`, `tests/check-allowlist.sh`,
  `tests/smoke-degit.sh`) and a repo-guarded CI workflow.
- Community-health files: `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SECURITY.md`,
  issue/PR templates, and an ADR template under `docs/decisions/`.

### Changed

- Cross-agent review is now **recommended for high-impact/irreversible plans**
  rather than mandatory on every multi-step task, and it checks whether the other
  CLI exists before shelling out — removing first-run friction for users without a
  second CLI installed.
- `.rules` carries a soft-cap anti-bloat rule; `decisionLog` documents
  supersede-don't-delete; `update-memory` prunes `.rules` and supersedes decisions.

### Fixed

- The shipped `memory-bank/` is now clean starter templates. It previously carried
  basecamp's own live development state, which every `npx degit` consumer inherited.
  basecamp's real bank moved to a gitignored `memory-bank.local/`.
- Resolved the `AGENTS.md` "optional second opinion" vs "never skip" contradiction.
- Brought the Claude/Codex `review`, `breakdown`, and `sync-upstream` adapters back
  to parity; fixed a duplicate step number in the `ask-codex`/`ask-claude` workflows.
- Fixed the broken file-tree rendering and tightened install instructions in the README.

[0.1.0]: https://github.com/gusfeliciano/basecamp/releases/tag/v0.1.0

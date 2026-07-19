# Changelog

All notable changes to Serel Memory (formerly Basecamp) are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project aims to
follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html) once it reaches 1.0.

## [Unreleased]

No changes yet.

## [0.3.0] — 2026-07-19

The Basecamp → Serel Memory identifier cutover. Ends the v0.x compatibility
contract that 0.2.0 opened; the contract's history is preserved in
`docs/research/2026-07-19-v0x-compat-history.md`.

### Changed

- **Provenance anchor renamed:** `.serel-memory.json` is now the single anchor
  filename, replacing `.basecamp.json` (same JSON schema:
  `{"upstream","ref","linked"}`). `sync-upstream` reads and writes only the new
  name, and the sync allowlist invariant now guards the new name.
- **`sync-upstream` fails fast on a legacy-only anchor.** Finding a
  `.basecamp.json` with no `.serel-memory.json` stops the sync with a
  migrate-first message — the project is never silently treated as unanchored
  and no baseline is silently reconstructed.
- README install paths and examples pin `v0.3.0` and write `.serel-memory.json`.

### Removed

- **`BASECAMP_HOOKS` fallback.** `SEREL_MEMORY_HOOKS=off` is the only hook kill
  switch; the legacy spelling no longer disables the hooks.
- **Legacy upstream aliasing.** `sync-upstream` no longer treats
  `gusfeliciano/basecamp` as equivalent to `madeordinary/serel-memory`; any
  remote/anchor slug mismatch is surfaced for the user to resolve.

### Migrating a v0.x install

1. Refresh the vendored tooling (`.claude/commands/`, `.agents/skills/`,
   `hooks/`, `CLAUDE.md`) from the `v0.3.0` tag. Replace files automatically
   only when they are byte-identical to a known upstream vintage (v0.1.0 or
   v0.2.0); merge or keep locally modified files individually.
2. Rename the anchor: `git mv .basecamp.json .serel-memory.json` (or plain
   `mv` if untracked), then set `"ref": "v0.3.0"` after the tooling refresh
   verifies clean.
3. Replace any use of `BASECAMP_HOOKS=off` with `SEREL_MEMORY_HOOKS=off`
   (shell profiles, CI, direnv).
4. If an `upstream` git remote or anchor still points at the old
   `gusfeliciano/basecamp` slug, normalize it to
   `https://github.com/madeordinary/serel-memory.git`.

## [0.2.0] — 2026-07-18

### Added

- `SEREL_MEMORY_HOOKS=off` as the preferred hook kill switch. The legacy
  `BASECAMP_HOOKS=off` spelling remains supported for every v0.x release; either
  variable disables the hooks.
- `.basecamp.json` provenance anchor: installs are now pinned and record the upstream
  version they started from; `sync-upstream` reads the anchor for precise
  what-changed-upstream reports, reconstructs a `"linked": true` anchor when missing,
  and advances it after a sync. The allowlist test now also guarantees the anchor is
  never in sync scope.
- "What makes it different" section in the README.
- Markdown lint (`markdownlint-cli2`) and link check (`lychee`) in CI; repo-wide
  markdown cleanup to zero lint errors.
- "Making changes" guidance in `AGENTS.md`: four execution-discipline principles
  (think before coding, simplicity first, surgical changes, goal-driven execution)
  read every session by both CLIs — distilled from Andrej Karpathy's observations
  on LLM coding pitfalls and `multica-ai/andrej-karpathy-skills` (MIT).
- Cross-agent review upgrades, validated by real downstream usage: anchored plan
  reviews now end with a greppable `VERDICT: APPROVE | REVISE | RETHINK` line
  (defined in the contract doc; requested by the `ask-codex`/`ask-claude` and
  `breakdown` cross-agent prompts and enforced by the parity test); the diff-native `codex review` subcommand is documented
  (`--uncommitted`/`--base`/`--commit`, including its no-staged-only caveat);
  `--output-last-message` is noted as a lighter output-capture aid; a
  no-model-pinning policy bullet keeps prompts and docs from going stale; and an
  opt-in **mandatory review gate** preset is documented for teams that want a
  hard gate — the shipped "recommended" default is unchanged.
- Cross-agent doc: "patience scales with intent" — user-requested reviews get
  time to finish (check the captured output file for growth before killing a
  long run; web search runs server-side, so sandboxing doesn't stall it); the
  hard timeout applies to opportunistic background passes only.

### Changed

- Renamed the project from Basecamp to **Serel Memory** and moved its canonical
  repository identity to `madeordinary/serel-memory`. Existing history, the
  `v0.1.0` tag, and MIT attribution are preserved.
- Kept `.basecamp.json` as the single provenance-anchor filename for v0.x.
  `sync-upstream` now defaults to the canonical repository while treating
  `gusfeliciano/basecamp` anchors and remotes as equivalent during the
  compatibility window. See `docs/basecamp-compatibility.md`.
- Updated CI to run under the canonical repository slug. The temporary former-
  slug guard was removed after the canonical post-transfer run passed.
- `breakdown` now attaches a `verify:` check to each step, reframes imperative
  steps as verifiable goals, and surfaces multiple interpretations instead of
  silently picking one. `review` gains explicit simplicity and scope-discipline
  checks. Both updates apply to the Claude command and the Codex skill.
- The `AGENTS.md` working agreement is refined from downstream field use:
  plan-level approval now comes with lane-level autonomy (no per-file
  re-asking inside an approved scope); surgical changes gain a bounded
  "fix the class, not just the instance" sibling-sweep exception; and
  goal-driven execution adds "judge gates by exit code, never by grepping
  output for success strings".

## [0.1.0] — 2026-05-30

First tagged release, originally published as Basecamp. The tag and commit history
remain intact. Pin it from the canonical home with
`npx degit madeordinary/serel-memory#v0.1.0`.

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
  Basecamp's own live development state, which every `npx degit` consumer inherited.
  Basecamp's real bank moved to a gitignored `memory-bank.local/`.
- Resolved the `AGENTS.md` "optional second opinion" vs "never skip" contradiction.
- Brought the Claude/Codex `review`, `breakdown`, and `sync-upstream` adapters back
  to parity; fixed a duplicate step number in the `ask-codex`/`ask-claude` workflows.
- Fixed the broken file-tree rendering and tightened install instructions in the README.

[Unreleased]: https://github.com/madeordinary/serel-memory/compare/v0.3.0...HEAD
[0.3.0]: https://github.com/madeordinary/serel-memory/releases/tag/v0.3.0
[0.2.0]: https://github.com/madeordinary/serel-memory/releases/tag/v0.2.0
[0.1.0]: https://github.com/madeordinary/serel-memory/releases/tag/v0.1.0

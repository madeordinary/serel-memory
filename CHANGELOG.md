# Changelog

All notable changes to Serel Memory (formerly Basecamp) are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project aims to
follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html) once it reaches 1.0.

## [Unreleased]

Guided setup and a local, Git-excluded install. None of this is in 0.6.0.

### Added

- `docs/serel-setup.md`, the canonical setup guide (named so it does not
  collide with a project's own `docs/setup.md`), and a copyable setup prompt
  near the top of the README. The agent resolves the scope and looks before it
  asks, then asks only what it could not detect, one question at a time and at
  most four (stage; Serel Memory, Serel Kit packs, or both; agents; what stays
  out of Git). It shows one plan with every path and whether Git sees it, and
  waits for approval unless it was already given. Serel Memory's own files
  are never mistaken for the project's code. Seeding keeps its own approval
  step. Kit packs keep Kit's requirements: `writing` alone seeds nothing;
  `verify` needs Serel Memory and an initialized bank, so the plan shows the
  install or seed it needs, each with its own approval. The guide carries a
  file-ownership table and the Memory/Kit shared and local combinations.
- `install.sh <target-repo> --local [--apply]`: installs the framework and the
  starter bank into one clone and keeps them out of Git through the
  repository's own `info/exclude` (shared by linked worktrees), with exact
  lines per framework file and `/memory-bank/` as the one owned subtree.
  Exclusions are written and verified before any file is copied. It never
  edits, stages or untracks tracked files; refuses tracked or differing
  destinations (tracked names compared without case, so a tracked `.RULES`
  stops it), existing names that differ only in case, symlinks, hard links,
  nested repositories and ignore negations before writing anything, including
  one that keeps the `memory-bank/` folder visible while each template is
  ignored; checks that folder itself again after copying; leaves an existing
  `AGENTS.md` alone; rolls back an ordinary failure, exclusions included; and
  is safe to re-run. It holds the root bank only: at a project scope of a
  local install, start's setup and the seed workflows stop before writing,
  because scopes listed later are not excluded. The anchor names a clean
  release tag (`vX.Y.Z[-pre]`), otherwise the clean commit's SHA, or, for
  uncommitted source changes, the commit with `"linked": true`. The installer
  runs from a checkout and is not copied into projects.
- `/start setup` and `$start setup` enter setup whatever the bank's state;
  both start adapters also route a missing or blank bank there, scope-aware.
  An initialized bank is never re-seeded, but setup can still add Kit packs
  beside it; `verify` beside a blank or partial bank brings the seed workflow
  into the plan. An initialized bank's plain `start` is unchanged.
- `tests/smoke-install.sh` (preview, apply, idempotence, collisions, case-only
  names, existing instructions, negations, linked worktrees, source/target
  safety, rollback, provenance) and a fresh-session acceptance guide for the
  agent CLIs, `tests/local-setup-acceptance.md`.

### Changed

- `/discover`, `/from-prd` and `/init-memory` (both adapters) reuse answers
  already given during setup and share one partial-bank rule: files with real
  content are kept exactly as they are and read as given, only the missing,
  empty or template-only files are proposed, and a fully initialized bank is
  not re-seeded. A hand-written `projectbrief.md` no longer turns `/discover`
  away. Code plus a spec routes to `/init-memory`: the code describes what
  exists, the spec stays planned intent. The code check runs in the selected
  scope, after scope resolution.
- `docs/serel-setup.md` joins the sync allowlist and the drift checker's
  framework baseline; `tests/check-allowlist.sh` keeps the checker's and
  installer's copies of the list equal to the allowlist.
- `sync-upstream` stops while any of Serel Memory's own framework files is
  Git-excluded, not only when the anchor is: Git cannot see local edits to
  excluded files, so a restore could overwrite them. Updating a local install
  is not supported yet. Another tool's Git-excluded files in the same
  folders, such as Kit packs installed with `--local`, do not stop it.
- The drift checker skips its framework baseline comparison, with an `INFO`
  line and `baseline: unavailable`, when Serel Memory's own framework files
  are Git-excluded, instead of vouching for bytes `git diff` never read.
  Another tool's excluded files there do not trigger the skip.
- The README's existing-project install copies only the two framework docs
  into `docs/`, so Serel Memory's research notes and decision records no
  longer land in the project.

## [0.6.0] — 2026-09-23

Memory accuracy. The 0.5.0 drift check settles what a repository can prove;
this release covers the judgment around it. `/analyze` audits a bank against
the code and reports documentation drift, possible regressions, and missing
evidence or information, without editing anything. `/update-memory` now runs
a required capture-and-reconcile pass: it records durable information the bank
is missing and corrects stale claims about what changed, stable files
included. The template also stops shipping the `CLAUDE.md` shim: `AGENTS.md`
is its one instruction file.

Upgrade from 0.5.0 or earlier: run `/sync-upstream` (or `$sync-upstream`)
twice. The installed sync workflow still lists `CLAUDE.md` in its allowlist,
so on the first run skip that upstream deletion; do not run `git restore` on
it or delete a customized file. That run pulls the updated sync workflow and
checker; review and commit what it restored, because sync needs clean
framework files to start. The second run reviews retiring the shim with the
new safeguards.
Loading `AGENTS.md` without the shim needs Claude Code v2.1.277 or later on a
supported provider; see the README compatibility notes.

### Added

- `/analyze` and `$analyze`: a read-only memory accuracy audit with explicit
  scope and coverage, evidence-backed findings, and separate classifications
  for documentation drift, possible regressions, missing evidence and missing
  durable information. It preserves intent and dated history, reports the
  deterministic checker separately, and leaves corrections for a reviewed
  memory update. Synthetic acceptance exercises cover both agent CLIs.

### Changed

- `AGENTS.md` is the only instruction file shipped by the template. Claude
  Code's AGENTS fallback requires v2.1.277 or later on a supported provider
  with instruction-file loading enabled. Older versions and unsupported
  providers can keep a project-owned `CLAUDE.md` import. See README compatibility
  notes for existing Claude instruction files that suppress fallback.
- `sync-upstream` and the drift checker no longer manage `CLAUDE.md`.
  Updated sync workflows offer removal only for the unchanged legacy shim,
  after compatibility is confirmed; customized files are preserved. Upstream
  deletions are reported separately and never passed to `git restore`.
- `/update-memory` and `$update-memory` now require a capture and reconciliation
  pass: inspect session evidence for missing durable information, then reconcile
  live claims about changed subjects across the selected bank. Stable files may
  have stale facts corrected without a product-intent change. Decisions and
  dated history are preserved; unsupported claims and possible regressions are
  reported explicitly. The optional independent audit remains optional.
- Contributors run `bash tests/ci.sh`, the same preflight GitHub Actions runs:
  pinned ShellCheck, every Bash suite, and locked Markdown lint. See
  `CONTRIBUTING.md`.

### Fixed

- The drift check no longer reads a documented marker as a broken one. A bank
  that writes out `verified: <sha> <path>` to explain the syntax was reported
  as declaring evidence at an unresolvable revision, which pushed a healthy
  bank to exit 2. An angle-bracket placeholder is now skipped. Found by
  running the checker against this project's own bank.

## [0.5.0] — 2026-09-09

The drift check. A bank goes stale quietly: a claim written months ago keeps
reading as fact long after the code under it moved. `bin/serel-memory check`
answers the part of that a machine can settle — offline, read-only, and
explicit about what it left alone. Everything else in this release came out of
running the framework for real: the first downstream sync of 0.4.0 exposed
three faults in `sync-upstream`, all fixed here with regression tests.

Upgrade from 0.4.0: run `/sync-upstream` (or `$sync-upstream`). The checker
arrives as `bin/serel-memory` and needs `jq`; nothing runs it for you except
`/start` and `/update-memory`, and it blocks neither.

### Added

- **Drift check.** `bin/serel-memory check [--scope <path>]` is a read-only,
  offline pass over the effective bank: it verifies the anchor parses, the
  seven core files exist and are not still template scaffolding, retention
  targets are met, and every `verified: <sha> <path>...` evidence marker still
  matches the repo at `HEAD`. Findings are `DRIFT` / `STALE` / `INCOMPLETE` /
  `WARN` / `INFO` plus one summary line; exit 0 clean, 1 drift or stale, 2 an
  assessment could not finish. It never judges whether a bank line is *true* —
  unmarked bullets are counted, not graded — and it never uses the network.
  `/start` and `/update-memory` report its summary when it is present; it
  blocks neither. Requires `jq`. Contract: `docs/workflow-contract.md`
  "Drift check"; rationale: `docs/decisions/002-deterministic-drift-checker.md`.

### Fixed

- `sync-upstream` (both adapters) resolves the anchor explicitly: `git fetch
  upstream main` does not fetch tags, so a tag anchor such as `v0.3.0` never
  resolved and the "changed since anchor" report came back empty. The anchor
  is now fetched with `--no-tags` into a private ref
  (`refs/serel-memory/anchor`), never into the project's own tags. Found on
  the first real downstream sync.
- `sync-upstream` advances the anchor only after at least one file was
  restored (or the user explicitly skipped everything); an empty restore
  no longer moves it.
- `sync-upstream` offers back allowlisted framework files the project
  deleted that did not change upstream (they never appear in the anchor
  diff). `tests/smoke-sync.sh` now uses a tag anchor and a deleted
  framework doc, and runs the documented resolve snippet from both adapters.

### Changed

- Contract "Clean stop": the Checkpoint is the resume note (branch and HEAD,
  uncommitted, verified, first action); `wip:` commits only on a requested
  pause over the session's own changes; inherited completion claims are
  re-verified on resume. Reflected in the pre-compact hook and
  `/update-memory`.
- Learning routing: a repeated `.rules` entry or recurring correction first
  asks why the existing guidance did not take, then proposes a test or hook
  check (`/update-memory`, `/retro`, contract "Memory writes").
- `/review` and `/security-check` print one `DISAGREEMENTS:` line per
  explicit contradiction between the two passes; agreement is confidence,
  not priority.
- `decisionLog.md` entries follow *decision / why / evidence / result*
  (contract "Memory writes", template hint).

## [0.4.0] — 2026-09-09

Two field-driven additions: a retention layer that keeps the two volatile
bank files bounded without losing history, and opt-in scoped banks for repos
that host several initiatives. Repos without `scopes` see only the retention
step in `/update-memory`; the session read, hooks, and sync behave as before.

Upgrade from 0.3.0: run `/sync-upstream` (or `$sync-upstream`) and start a
fresh session before adding `"scopes"` to `.serel-memory.json`. Using scopes
requires `jq`; Serel Memory itself still has no dependency.

### Added

- **Scoped banks (opt-in).** A repo may list project folders under `"scopes"`
  in `.serel-memory.json`; each project root then carries its own full bank
  and `.rules`. Every workflow resolves exactly one bank per invocation —
  `--scope <path>` (`.` = root), else the current directory, else the root —
  with no remembered selection. At the root, `/start` and the SessionStart
  hook list project selectors without reading any project bank. The shared
  resolver `hooks/lib/resolve-scope.sh` drives both hooks; the rule, the
  `.rules` inheritance model, scope-relative artifacts, and the non-code
  workspace guidance live in `docs/workflow-contract.md` "Resolving scope".
  `tests/smoke-scopes.sh` covers explicit/cwd/root selection, unknown and
  uninitialized scopes, degraded configurations (overlap, missing dir, bad
  JSON, no `jq` → single-bank with a warning), overlay composition, and
  unchanged hook output for repos without `scopes` (SessionStart identical
  to 0.3.0; PreCompact differs only by the retention step).
- **Retention layer.** `hooks/lib/rotate-check.sh` (read-only) measures
  `activeContext.md` and `progress.md` against soft targets — 200 lines /
  12 KB, and the 10 newest milestones — and selects the oldest historical
  entries to rotate verbatim into `memory-bank/archive/<file>-<YYYY-MM>.md`.
  Current-state sections are never rotated; nothing is deleted. Contract in
  `docs/workflow-contract.md` "Retention"; `tests/smoke-retention.sh` proves
  the selections are lossless and the predictions exact.
- A repository-root `.serel-memory.json` provenance anchor for the upstream
  repository itself.

### Changed

- `sync-upstream` (both adapters) is explicitly repo-root anchored and updates
  the anchor's `ref`/`linked` in place with `jq`, preserving every other key
  (such as `scopes`); without `jq` it stops with a one-line manual edit
  instead of regenerating the file. `tests/smoke-sync.sh` now runs the
  documented snippets verbatim from both adapters, including reconstruction
  of a missing anchor and a sync started from inside a project folder.
- All 15 bank-touching workflow pairs carry a one-line scope pointer;
  `/start` gains a gated `Scope:` audit row and root-level project listing;
  `/update-memory` never writes to two scopes in one pass.
- `/update-memory` and `$update-memory` gain a required retention step: they
  run the helper on the *proposed* files and fold any rotation into the same
  confirmation as the content diffs, then re-check after writing. The
  pre-compact hook points at that step. This applies to every install.
- `memory-bank/archive/` is excluded from routine reads (session read list,
  `/start`, `/update-memory`, `/handoff`, both hooks).
- `tests/smoke-migrate-v02-v03.sh` enumerates refresh candidates from the
  upstream export under the allowlist, so files added upstream after the
  fixture's vintage (such as `hooks/lib/`) are installed by a migration.
- `.gitattributes` is excluded from archive/degit exports along with the
  maintainer-only files it governs, so downstream copies do not inherit
  upstream export rules.
- The June 6 improvement-roadmap document is explicitly marked superseded by
  the July 10 rescope recorded in the maintainer decision log.

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

[Unreleased]: https://github.com/madeordinary/serel-memory/compare/v0.6.0...HEAD
[0.6.0]: https://github.com/madeordinary/serel-memory/releases/tag/v0.6.0
[0.5.0]: https://github.com/madeordinary/serel-memory/releases/tag/v0.5.0
[0.4.0]: https://github.com/madeordinary/serel-memory/releases/tag/v0.4.0
[0.3.0]: https://github.com/madeordinary/serel-memory/releases/tag/v0.3.0
[0.2.0]: https://github.com/madeordinary/serel-memory/releases/tag/v0.2.0
[0.1.0]: https://github.com/madeordinary/serel-memory/releases/tag/v0.1.0

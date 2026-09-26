# Contributing to Serel Memory

Thanks for wanting to improve Serel Memory. It's a small, opinionated kit, so contributions that keep it small are the most welcome.

> **Using Serel Memory in your own project?** This file, `CODE_OF_CONDUCT.md`, `SECURITY.md`, `CHANGELOG.md`, and `.github/` are Serel Memory's *own* project metadata. After you install the framework into your project you can delete them — they aren't part of the memory-bank framework, and `sync-upstream` never touches them.

## The shape of the repo

Serel Memory has four kinds of files:

- **Synced framework files** — the workflows (Claude commands + Codex skills), the hooks, and the framework docs. `sync-upstream` keeps these in step with the upstream repo. The exact allowlist lives in `.claude/commands/sync-upstream.md`.
- **Shipped-once content** — the `memory-bank/` templates and `.rules`. Copied in at install, then **owned by the downstream project** and never synced — so a sync can't overwrite a user's context.
- **Project metadata** — `docs/decisions/` and the OSS files above (`CONTRIBUTING`, `SECURITY`, `.github/`, …). The downstream project's to keep or delete.
- **Installer tooling** — `install.sh` runs from a Serel Memory checkout to make a local, Git-excluded install. It copies the synced framework files plus the shipped-once templates, is never copied into a project, and is export-ignored. Its framework list must match the sync allowlist (`tests/check-allowlist.sh`); `tests/smoke-install.sh` covers it.

When you add or change something, know which kind it is.

## The one rule: dual-adapter parity

Every workflow ships **two adapters plus a manifest**, and they must stay in sync:

| Tool | File |
|------|------|
| Claude Code | `.claude/commands/<name>.md` (a slash command) |
| Codex | `.agents/skills/<name>/SKILL.md` (a skill) |
| Codex | `.agents/skills/<name>/agents/openai.yaml` (the skill's display manifest) |

The one intentional exception is the cross-agent helper, which names the *other* agent on each side: `/ask-codex` (Claude) ↔ `$ask-claude` (Codex). They are the same workflow, inverted.

`tests/check-parity.sh` enforces this. If you add `/foo`, you must add `$foo` (SKILL.md + openai.yaml) or CI fails. There is deliberately **no generator** — Serel Memory is pure markdown with no build step. Parity is a 30-second manual step plus a check, not a toolchain.

## Adding or changing a workflow

1. Follow `docs/workflow-contract.md`: state the trigger, required reads, allowed writes, output shape, and stop conditions.
2. Write the Claude command and the Codex skill so they produce the **same** output contract. Diff a sibling pair (e.g. `start`) to match structure.
3. Add the `agents/openai.yaml` manifest (copy a sibling's and edit `display_name`, `short_description`, `default_prompt`).
4. If it's a new workflow, add it to the workflow table in `README.md` and the workflow list in `AGENTS.md`.
5. Run the checks below.

## Invariants (please don't break these)

These are load-bearing decisions. Change them only with a clear reason in the PR:

- **The sync allowlist never includes `memory-bank/`, `.rules`, or `.serel-memory.json`.** Syncing user memory or the project's provenance anchor would clobber a downstream project's context. `tests/check-allowlist.sh` enforces it.
- **The shipped `memory-bank/` is clean templates**, not Serel Memory's own bank. Serel Memory's real working bank lives in a gitignored `memory-bank.local/` (maintainer-only). `tests/smoke-degit.sh` asserts the export stays clean.
- **Bare workflow names** (`/start`, not `/serel-memory:start`). These are core workflows, not a namespaced plugin.
- **The v0.3.0 identifier cutover stays clean.** `.serel-memory.json` is the only
  provenance-anchor filename on live surfaces, `SEREL_MEMORY_HOOKS` is the only
  hook kill-switch spelling, and the retired pre-rename repository slug appears
  nowhere outside `CHANGELOG.md` and `docs/research/` (the historical record).
  `tests/check-compatibility.sh` enforces it.
- **No runtime dependencies, no build step.** Markdown, plus optional bash hooks. If a change needs a package manager, it probably belongs in a fork.

## Running the checks

```bash
bash tests/ci.sh           # ShellCheck, every check/smoke suite, Markdown lint
bash tests/ci.sh checks    # ShellCheck and Bash suites only
bash tests/ci.sh docs      # Markdown lint only
```

Use a full Git checkout with release tags (`git fetch --unshallow --tags` for
a shallow clone, otherwise `git fetch origin --tags`), Bash, `jq`, and
Python 3 (the memory-use fixture builds a synthetic Python project).
Markdown lint requires the Node version in `.github/ci/node-version` and its
bundled npm. These are maintainer tools, not framework runtime dependencies.

The runner uses ShellCheck **0.11.0**. If that exact version is not on PATH,
it downloads the official Linux/macOS Intel/ARM binary into a temporary
directory and verifies its SHA256; `curl`, `tar`, and `shasum` are required
for that bootstrap. Markdown lint installs **0.23.3** and its locked
dependencies from `.github/ci/package-lock.json` into a temporary directory.
Downloads require network access and fail the check if unavailable. Nothing
is installed globally or left in the repository.

GitHub runs these same commands, plus a required external link check with
lychee **0.24.2** and `lychee.toml`. The local command does not run the link
check; to reproduce it separately with that version installed, run
`lychee --config lychee.toml --no-progress './**/*.md'`.
CI runs only on `madeordinary/serel-memory` and self-disables in unrelated
forks and copies. The fixture suites read committed `HEAD` for archives and
clones, so final validation must also run after committing the candidate.

Update tool pins deliberately: change `.github/ci/shellcheck.sh` and its
official archive checksums together; update the Markdown manifest and lockfile
from `.github/ci/`; update `.github/ci/node-version` for Node. Keep action
commit pins and lychee's version in the workflow current through reviewed
changes. Rerun the complete preflight and GitHub checks after each update.

## Behavior exercises

The checks prove structure and mechanics, not what an agent does with a
prompt. When a change is meant to alter agent behavior, run the matching
manual exercise in fresh CLI sessions and record what you observed:
`tests/analyze-acceptance.md` (`/analyze`), `tests/local-setup-acceptance.md`
(local installs and setup routing), and `tests/memory-use-acceptance.md` (how
`breakdown`, `review`, and `update-memory` use and write memory). Their
builders create synthetic repositories outside any Git work tree. They are
contributor tools, in neither the sync allowlist nor the installer's payload.

## Style

Match the voice already in the repo: terse, concrete, opinionated. Prefer one focused workflow over a broad persona. Don't bloat the memory bank — it's signal, not journal.

## Maintainer note: dogfooding

Serel Memory develops itself using its own pattern. The real working bank is the gitignored `memory-bank.local/`; read it at the start of a session when working *on Serel Memory* (the tracked `memory-bank/` is intentionally blank templates for downstream users).

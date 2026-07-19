# Contributing to Serel Memory

Thanks for wanting to improve Serel Memory. It's a small, opinionated kit, so contributions that keep it small are the most welcome.

> **Using Serel Memory in your own project?** This file, `CODE_OF_CONDUCT.md`, `SECURITY.md`, `CHANGELOG.md`, and `.github/` are Serel Memory's *own* project metadata. After you install the framework into your project you can delete them — they aren't part of the memory-bank framework, and `sync-upstream` never touches them.

## The shape of the repo

Serel Memory has three kinds of files:

- **Synced framework files** — the workflows (Claude commands + Codex skills), the hooks, and the framework docs. `sync-upstream` keeps these in step with the upstream repo. The exact allowlist lives in `.claude/commands/sync-upstream.md`.
- **Shipped-once content** — the `memory-bank/` templates and `.rules`. Copied in at install, then **owned by the downstream project** and never synced — so a sync can't overwrite a user's context.
- **Project metadata** — `docs/decisions/` and the OSS files above (`CONTRIBUTING`, `SECURITY`, `.github/`, …). The downstream project's to keep or delete.

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
tests/check-parity.sh                    # adapters paired
tests/check-allowlist.sh                 # sync scope safe
tests/check-compatibility.sh             # rename compatibility
tests/smoke-degit.sh                     # export ships clean templates
shellcheck hooks/*.sh tests/*.sh
npx --yes markdownlint-cli2 "**/*.md"    # markdown hygiene (config: .markdownlint-cli2.jsonc)
```

CI runs the same set plus a link check (`lychee`, config in `lychee.toml`). It
runs only on `madeordinary/serel-memory` and self-disables in unrelated forks
and copies.

## Style

Match the voice already in the repo: terse, concrete, opinionated. Prefer one focused workflow over a broad persona. Don't bloat the memory bank — it's signal, not journal.

## Maintainer note: dogfooding

Serel Memory develops itself using its own pattern. The real working bank is the gitignored `memory-bank.local/`; read it at the start of a session when working *on Serel Memory* (the tracked `memory-bank/` is intentionally blank templates for downstream users).

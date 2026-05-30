# Contributing to basecamp

Thanks for wanting to improve basecamp. It's a small, opinionated kit, so contributions that keep it small are the most welcome.

> **Using basecamp in your own project?** This file, `CODE_OF_CONDUCT.md`, `SECURITY.md`, `CHANGELOG.md`, and `.github/` are basecamp's *own* project metadata. After you install basecamp into your project you can delete them — they aren't part of the memory-bank framework, and `sync-upstream` never touches them.

## The shape of the repo

basecamp has two kinds of files:

- **Framework files** — the memory-bank templates, the workflows, the hooks, and the framework docs. These are what `sync-upstream` keeps in step with the upstream repo. The exact allowlist lives in `.claude/commands/sync-upstream.md`.
- **Project/starter content** — everything a downstream project owns after install: their `memory-bank/` content, `.rules`, `docs/decisions/`, and the OSS metadata above.

When you add or change something, know which kind it is.

## The one rule: dual-adapter parity

Every workflow ships **two adapters plus a manifest**, and they must stay in sync:

| Tool | File |
|------|------|
| Claude Code | `.claude/commands/<name>.md` (a slash command) |
| Codex | `.agents/skills/<name>/SKILL.md` (a skill) |
| Codex | `.agents/skills/<name>/agents/openai.yaml` (the skill's display manifest) |

The one intentional exception is the cross-agent helper, which names the *other* agent on each side: `/ask-codex` (Claude) ↔ `$ask-claude` (Codex). They are the same workflow, inverted.

`tests/check-parity.sh` enforces this. If you add `/foo`, you must add `$foo` (SKILL.md + openai.yaml) or CI fails. There is deliberately **no generator** — basecamp is pure markdown with no build step. Parity is a 30-second manual step plus a check, not a toolchain.

## Adding or changing a workflow

1. Follow `docs/workflow-contract.md`: state the trigger, required reads, allowed writes, output shape, and stop conditions.
2. Write the Claude command and the Codex skill so they produce the **same** output contract. Diff a sibling pair (e.g. `start`) to match structure.
3. Add the `agents/openai.yaml` manifest (copy a sibling's and edit `display_name`, `short_description`, `default_prompt`).
4. If it's a new workflow, add it to the tables in `README.md` and `AGENTS.md`.
5. Run the checks below.

## Invariants (please don't break these)

These are load-bearing decisions. Change them only with a clear reason in the PR:

- **The sync allowlist never includes `memory-bank/` or `.rules`.** Syncing user memory would clobber a downstream project's context. `tests/check-allowlist.sh` enforces it.
- **The shipped `memory-bank/` is clean templates**, not basecamp's own bank. basecamp's real working bank lives in a gitignored `memory-bank.local/` (maintainer-only). `tests/smoke-degit.sh` asserts the export stays clean.
- **Bare workflow names** (`/start`, not `/basecamp:start`). These are core workflows, not a namespaced plugin.
- **No runtime dependencies, no build step.** Markdown, plus optional bash hooks. If a change needs a package manager, it probably belongs in a fork.

## Running the checks

```bash
tests/check-parity.sh      # adapters paired
tests/check-allowlist.sh   # sync scope safe
tests/smoke-degit.sh       # export ships clean templates
shellcheck hooks/*.sh tests/*.sh
```

CI runs the same set (and only on `gusfeliciano/basecamp` — it self-disables in forks/copies).

## Style

Match the voice already in the repo: terse, concrete, opinionated. Prefer one focused workflow over a broad persona. Don't bloat the memory bank — it's signal, not journal.

## Maintainer note: dogfooding

basecamp develops itself using its own pattern. The real working bank is the gitignored `memory-bank.local/`; read it at the start of a session when working *on* basecamp (the tracked `memory-bank/` is intentionally blank templates for downstream users).

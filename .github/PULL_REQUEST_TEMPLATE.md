<!-- Thanks for contributing! Keep changes small and focused. -->

## What this changes

<!-- One or two sentences. -->

## Why

<!-- The problem it solves. Link an issue if there is one. -->

## Checklist

- [ ] If I added/changed a workflow, I updated **both** adapters (`.claude/commands/<name>.md` and `.agents/skills/<name>/SKILL.md` + `agents/openai.yaml`)
- [ ] I updated the workflow table in `README.md` and the workflow list in `AGENTS.md` if I added a workflow
- [ ] `tests/check-parity.sh`, `tests/check-allowlist.sh`, and `tests/smoke-degit.sh` pass
- [ ] `shellcheck hooks/*.sh tests/*.sh` is clean (if I touched shell)
- [ ] The change keeps basecamp small — no build step, no runtime dependency, no namespace creep
- [ ] I added a `CHANGELOG.md` entry under `[Unreleased]`/`[0.1.0]` if user-facing

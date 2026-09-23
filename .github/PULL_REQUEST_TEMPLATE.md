<!-- Thanks for contributing! Keep changes small and focused. -->

## What this changes

<!-- One or two sentences. -->

## Why

<!-- The problem it solves. Link an issue if there is one. -->

## Checklist

- [ ] If I added/changed a workflow, I updated **both** adapters (`.claude/commands/<name>.md` and `.agents/skills/<name>/SKILL.md` + `agents/openai.yaml`)
- [ ] I updated the workflow table in `README.md` and the workflow list in `AGENTS.md` if I added a workflow
- [ ] `bash tests/ci.sh` passes with the pinned tools (all Bash suites and Markdown lint)
- [ ] GitHub's required `checks` and `docs` jobs pass, including the external link check
- [ ] The change keeps Serel Memory small — no build step, no runtime dependency, no namespace creep
- [ ] I added a `CHANGELOG.md` entry under `[Unreleased]`/`[0.1.0]` if user-facing

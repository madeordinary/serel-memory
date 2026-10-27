<!-- Thanks for contributing! Keep changes small and focused. -->

## What this changes

<!-- One or two sentences. -->

## Why

<!-- The problem it solves. Link an issue if there is one. -->

## Checklist

- [ ] If I added/changed a workflow, I edited the source `.agents/skills/<name>/SKILL.md` and ran `bash tests/check-single-source.sh --write` (plus `agents/openai.yaml` for a new workflow)
- [ ] I updated the workflow table in `README.md` and the workflow list in `AGENTS.md` if I added a workflow
- [ ] `bash tests/ci.sh` passes with the pinned tools (all Bash suites and Markdown lint)
- [ ] GitHub's required `checks` and `docs` jobs pass, including the external link check
- [ ] The change keeps Serel Memory small — no build step, no runtime dependency, no namespace creep
- [ ] I added a `CHANGELOG.md` entry under `[Unreleased]`/`[0.1.0]` if user-facing

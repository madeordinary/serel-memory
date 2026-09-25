---
description: Initialize the memory bank by analyzing the existing codebase
---

# /init-memory

Use this when Serel Memory has just been dropped into an existing project and the memory bank files are still empty or template-only. You'll read the codebase and propose what each file should contain — the user reviews and edits before anything gets written.

**Effective bank:** if `memory-bank.local/` exists (upstream Serel Memory development only), it is the working bank — the empty/template-only check and any proposed writes target it, not the tracked starter templates. See "Resolving the effective bank" in `docs/workflow-contract.md`.

**Scope:** resolve which bank this targets per "Resolving scope" in `docs/workflow-contract.md` — an optional `--scope <path>` argument selects a project bank when the repo configures `scopes`; otherwise the root bank, as always.

**Local install at a project scope:** after resolving the scope, and only when it is not the root, check from the repository root whether Serel Memory is installed locally (the test in "Setup routing" in `docs/workflow-contract.md`):

```bash
top="$(git rev-parse --show-toplevel)"
if [ -n "$(git -C "$top" ls-files --others --ignored --exclude-standard -- bin/serel-memory docs/workflow-contract.md hooks/lib/resolve-scope.sh)" ] ||
  git -C "$top" check-ignore -q .serel-memory.json; then echo "LOCAL INSTALL"; fi
```

If it prints `LOCAL INSTALL`, stop before any other step. A local install holds the root bank only: it excludes the root `memory-bank/` and `.rules`, and `scopes` listed later do not extend that, so a bank seeded at this scope would be visible to Git. Say so, write nothing, leave any existing files at this scope, the exclusions, `.gitignore` and instruction files as they are, and offer the supported choices: the root bank (`--scope .`) or a shared, committed install, where scoped banks work. Never un-ignore, untrack or force-add anything.

**Existing bank content:** check each core file in the effective bank. If every one has real content beyond the template placeholders, the bank is initialized: do not re-seed it; point to `/start` to resume or `/update-memory` to correct it. If only some do (a partial bank, such as a `projectbrief.md` the user wrote), keep those files exactly as they are, read them first as given, and propose only the files that are missing, empty, or template-only; where the code disagrees with an existing file, say so instead of rewriting it.

**Setup context:** if setup already ran in this session (`docs/serel-setup.md`, or start's setup mode), treat its answers as given (stage, spec path, users) and ask only about what is still missing. The proposal and approval steps below are unchanged.

Steps:

1. Read the repo structure. Use `ls` and `find` to map the top-level layout. Skip `node_modules/`, `.git/`, `dist/`, `build/`.
2. Read the existing `README.md` and anything in `docs/` for stated purpose, setup, and architecture.
3. Read the package manifest (`package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, `Gemfile`, etc.) for stack, dependencies, and scripts.
4. Skim the source tree to understand component boundaries. Don't read every file — sample enough to see the architecture.
5. Run `git log --oneline -20` for recent history and `git branch -a` to see active branches.
6. If the user named a PRD or spec, or setup found one, read it after the code. The code, tests, and docs about current behavior say what exists; the spec supplies intent and planned scope. Put spec-only items in the brief and product context, and in activeContext/progress as planned or not built yet, citing the spec; never record a spec requirement as working without evidence in the code.

Then propose contents for each memory bank file (in a partial bank, only the files still missing, empty, or template-only), in this order:

- **projectbrief.md** — what this project is, why it exists, success criteria. Infer from README, repo description, and code.
- **productContext.md** — user problem and UX goals. Often the hardest to infer from code alone; flag what needs user input.
- **systemPatterns.md** — architecture, key decisions, patterns in use. Visible from code structure and any architecture docs.
- **techContext.md** — stack, dependencies, dev setup. Read directly from manifests and config files.
- **decisionLog.md** — durable decisions already visible in docs, ADRs, architecture notes, or commits. If none are evident, say that no durable decisions have been recorded yet.
- **activeContext.md** — current focus. Infer from recent commits, active branches, and open work in progress.
- **progress.md** — what works, what's broken, status. Infer from existing tests, TODOs, open issues if visible.

For each file, present your proposal in this format:

```text
FILE: memory-bank/<name>.md
PROPOSAL:
<the proposed contents, including the template's heading structure>

CONFIDENCE: high / medium / low
REASONING: <one or two lines on what you based this on>
QUESTIONS FOR USER: <anything you genuinely couldn't infer — leave blank if none>
```

After all proposals, **stop and wait**. Do not write anything until the user reviews and approves (or revises).

Rules:

- If you can't infer something, say so explicitly. Don't fabricate to fill space.
- Prefer terse and accurate over comprehensive and speculative.
- Confidence should be honest: high only when you have direct evidence (README or code), low when guessing.
- If the project uses patterns or domain concepts you don't understand, flag them as questions. Don't pretend to understand.

Once the user confirms a proposal (with or without edits), write it to the file. Then move to the next.

---
name: init-memory
description: "Initialize memory-bank files by analyzing an existing codebase. Use when the memory bank has been added to a repo with code already present and the memory-bank files are blank, template-only, or partly filled."
---

# Init Memory

Use this skill when Serel Memory has been dropped into an existing project and the memory bank is still uninitialized.

**Effective bank:** if `memory-bank.local/` exists (upstream Serel Memory development only), it is the working bank — the uninitialized check and any proposed writes target it, not the tracked starter templates. See "Resolving the effective bank" in `docs/workflow-contract.md`.

**Scope:** resolve which bank this targets per "Resolving scope" in `docs/workflow-contract.md` — an optional `--scope <path>` argument selects a project bank when the repo configures `scopes`; otherwise the root bank, as always.

**Local install at a project scope:** after resolving the scope, and only when it is not the root, check from the repository root whether Serel Memory is installed locally (the test in "Setup routing" in `docs/workflow-contract.md`):

```bash
top="$(git rev-parse --show-toplevel)"
if [ -n "$(git -C "$top" ls-files --others --ignored --exclude-standard -- bin/serel-memory docs/workflow-contract.md hooks/lib/resolve-scope.sh)" ] ||
  git -C "$top" check-ignore -q .serel-memory.json; then echo "LOCAL INSTALL"; fi
```

If it prints `LOCAL INSTALL`, stop before any other step. A local install holds the root bank only: it excludes the root `memory-bank/` and `.rules`, and `scopes` listed later do not extend that, so a bank seeded at this scope would be visible to Git. Say so, write nothing, leave any existing files at this scope, the exclusions, `.gitignore` and instruction files as they are, and offer the supported choices: the root bank (`--scope .`) or a shared, committed install, where scoped banks work. Never un-ignore, untrack or force-add anything.

**Existing bank content:** check each core file in the effective bank. If every one has real content beyond the template placeholders, the bank is initialized: do not re-seed it; point to `$start` to resume or `$update-memory` to correct it. If only some do (a partial bank, such as a `projectbrief.md` the user wrote), keep those files exactly as they are, read them first as given, and propose only the files that are missing, empty, or template-only; where the code disagrees with an existing file, say so instead of rewriting it.

**Setup context:** if setup already ran in this session (`docs/serel-setup.md`, or start's setup mode), treat its answers as given (stage, spec path, users) and ask only about what is still missing. The proposal and approval steps below are unchanged.

## Workflow

1. Map the repo structure with fast shell tools. Skip `node_modules/`, `.git/`, `dist/`, and `build/`.
2. Read `README.md` and relevant docs for stated purpose, setup, and architecture.
3. Read package manifests such as `package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, or `Gemfile`.
4. Skim the source tree enough to understand component boundaries. Do not read every file unless needed.
5. Run `git log --oneline -20` and `git branch -a`.
6. If the user named a PRD or spec, or setup found one, read it after the code. The code, tests, and docs about current behavior say what exists; the spec supplies intent and planned scope. Put spec-only items in the brief and product context, and in activeContext/progress as planned or not built yet, citing the spec; never record a spec requirement as working without evidence in the code.
7. Propose contents for each memory-bank file (in a partial bank, only the files still missing, empty, or template-only) in this order:
   - `projectbrief.md`
   - `productContext.md`
   - `systemPatterns.md`
   - `techContext.md`
   - `decisionLog.md`
   - `activeContext.md`
   - `progress.md`

For each file, use this format:

```text
FILE: memory-bank/<name>.md
PROPOSAL:
<proposed contents, preserving the file's heading structure>

CONFIDENCE: high / medium / low
REASONING: <one or two lines on evidence>
QUESTIONS FOR USER: <anything that cannot be inferred>
```

After all proposals, stop and wait. Do not write anything until the user approves or revises.

## Rules

- If something cannot be inferred from code/docs/history, say so.
- Prefer terse and accurate over comprehensive and speculative.
- Treat code as the source of truth for current behavior.
- Treat the memory bank as the source of truth for intended behavior once initialized.

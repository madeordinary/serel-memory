---
name: from-prd
description: "Seed memory-bank files from an existing PRD, product brief, spec, or requirements document. Use when a new project has a source document but little or no code yet."
---

# From PRD

Use this skill when a project has a PRD, product brief, strategy doc, or similar source document, but little or no code yet. This sits between `$discover` for rough ideas and `$init-memory` for existing codebases.

**Effective bank:** if `memory-bank.local/` exists (upstream Serel Memory development only), it is the working bank — the substantive-content check and any proposed writes target it, not the tracked starter templates. See "Resolving the effective bank" in `docs/workflow-contract.md`.

**Scope:** resolve which bank this targets per "Resolving scope" in `docs/workflow-contract.md` — an optional `--scope <path>` argument selects a project bank when the repo configures `scopes`; otherwise the root bank, as always.

**Local install at a project scope:** after resolving the scope, and only when it is not the root, check from the repository root whether Serel Memory is installed locally (the test in "Setup routing" in `docs/workflow-contract.md`):

```bash
top="$(git rev-parse --show-toplevel)"
if [ -n "$(git -C "$top" ls-files --others --ignored --exclude-standard -- bin/serel-memory docs/workflow-contract.md hooks/lib/resolve-scope.sh)" ] ||
  git -C "$top" check-ignore -q .serel-memory.json; then echo "LOCAL INSTALL"; fi
```

If it prints `LOCAL INSTALL`, stop before any other step. A local install holds the root bank only: it excludes the root `memory-bank/` and `.rules`, and `scopes` listed later do not extend that, so a bank seeded at this scope would be visible to Git. Say so, write nothing, leave any existing files at this scope, the exclusions, `.gitignore` and instruction files as they are, and offer the supported choices: the root bank (`--scope .`) or a shared, committed install, where scoped banks work. Never un-ignore, untrack or force-add anything.

**Setup context:** if setup already ran in this session (`docs/serel-setup.md`, or start's setup mode), treat its answers as given (PRD path, stage, users, constraints) and ask only about what is still missing. The proposal and approval steps below are unchanged.

**Stage:** after resolving the scope, check the selected scope for meaningful product code, not counting Serel Memory's own files (its workflows, `hooks/`, `bin/serel-memory`, framework docs, bank templates, and the `tests/` and `.github/` a degit copy brings) or code in another scope. If there is some, this is the code-plus-spec case: stop and recommend `$init-memory` naming this PRD, with the same `--scope`. It inspects the implementation first and keeps the PRD as planned intent (see `docs/serel-setup.md`).

## Workflow

1. Determine the PRD path.
   - If the user provided a path, use it.
   - If not, look for likely files in `docs/`, the repo root, or filenames containing `prd`, `brief`, `spec`, `requirements`, or `product`.
   - If there are multiple plausible files, ask which one to use.
2. Read the PRD in full.
3. Check each core file in the effective bank. If every one has real content beyond the template placeholders, the bank is initialized: do not re-seed it; point to `$start` to resume or `$update-memory` to correct it. If only some do (a partial bank, such as a `projectbrief.md` the user wrote), keep those files exactly as they are, read them first as given, and propose only the files that are missing, empty, or template-only; where the PRD disagrees with an existing file, say so instead of rewriting it.
4. Extract what the PRD clearly says about:
   - Problem
   - User
   - Current workaround or status quo
   - Goals and success criteria
   - Minimum scope
   - Anti-scope
   - Constraints
   - Stack, platform, or architecture hints
   - Risks, open questions, and unresolved decisions
5. Before proposing memory-bank contents, present a clarifications checkpoint:

   ```text
   CLARIFYING QUESTIONS:
   - [question] or "(none - PRD is sufficient for initial seeding)"
   ```

   Ask at most 3 targeted follow-up questions for material gaps that would make the memory bank misleading if guessed. Skip questions where `TBD` is acceptable.
6. If there are clarifying questions, stop and wait for the user's answers before synthesis. If there are none, say so and proceed.
7. Propose contents for every memory bank file (in a partial bank, only the files still missing, empty, or template-only):
   - `memory-bank/projectbrief.md`
   - `memory-bank/productContext.md`
   - `memory-bank/systemPatterns.md`
   - `memory-bank/techContext.md`
   - `memory-bank/decisionLog.md`
   - `memory-bank/activeContext.md`
   - `memory-bank/progress.md`

Use this format for each proposal:

```text
FILE: memory-bank/<name>.md
PROPOSAL:
<proposed contents, preserving the file's heading structure>

CONFIDENCE: high / medium / low
SOURCE: <PRD section or evidence used>
QUESTIONS / ASSUMPTIONS: <only if needed>
```

After all proposals, stop and wait. Do not write anything until the user approves or revises.

## Output Quality

- Do not wrap an entire file proposal in a Markdown code fence if the proposed file itself contains fenced code blocks.
- If a proposal includes a code block, close the fence before continuing with the next heading or metadata line.
- Keep architecture sketches simple unless a code fence is genuinely useful.
- Keep `CONFIDENCE`, `SOURCE`, and `QUESTIONS / ASSUMPTIONS` outside the proposed file body.
- End by asking whether the user wants to approve, revise, or inspect a specific file first.

## Rules

- Treat the PRD as source material, not absolute truth.
- Do not invent details to fill empty sections. Use `<TBD>` or ask.
- Keep `systemPatterns.md` and `techContext.md` light unless the PRD states real technical decisions.
- Use `activeContext.md` to capture the immediate next focus after seeding the bank.
- Use `progress.md` to reflect that the project is initialized/planning unless code already exists.
- Use `decisionLog.md` only for explicit decisions in the PRD; otherwise state that no durable decisions have been recorded yet.
- Do not overwrite the PRD.
- Do not bloat the bank; preserve signal.

## Handoff

When approved files are written, end with: **"Memory bank seeded from the PRD. Use `$start` to verify the bootstrap, or use `$breakdown` to break the first implementation chunk into steps."**

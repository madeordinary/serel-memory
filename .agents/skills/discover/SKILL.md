---
name: discover
description: "Shape a brand-new project from a rough idea and seed memory-bank files. Use when there is no code yet, the memory bank is blank, template-only, or partly filled, or the user asks to discover, define, clarify, or scope a new project."
---

# Discover

Use this skill at the start of a new project when the user has an idea but has not articulated it as a brief. This is the inverse of `$init-memory`, which analyzes existing code.

**Effective bank:** if `memory-bank.local/` exists (upstream Serel Memory development only), it is the working bank — the bank check below and any proposed writes target it, not the tracked starter templates. See "Resolving the effective bank" in `docs/workflow-contract.md`.

**Scope:** resolve which bank this targets per "Resolving scope" in `docs/workflow-contract.md` — an optional `--scope <path>` argument selects a project bank when the repo configures `scopes`; otherwise the root bank, as always.

**Local install at a project scope:** after resolving the scope, and only when it is not the root, check from the repository root whether Serel Memory is installed locally (the test in "Setup routing" in `docs/workflow-contract.md`):

```bash
top="$(git rev-parse --show-toplevel)"
if [ -n "$(git -C "$top" ls-files --others --ignored --exclude-standard -- bin/serel-memory docs/workflow-contract.md hooks/lib/resolve-scope.sh)" ] ||
  git -C "$top" check-ignore -q .serel-memory.json; then echo "LOCAL INSTALL"; fi
```

If it prints `LOCAL INSTALL`, stop before any other step. A local install holds the root bank only: it excludes the root `memory-bank/` and `.rules`, and `scopes` listed later do not extend that, so a bank seeded at this scope would be visible to Git. Say so, write nothing, leave any existing files at this scope, the exclusions, `.gitignore` and instruction files as they are, and offer the supported choices: the root bank (`--scope .`) or a shared, committed install, where scoped banks work. Never un-ignore, untrack or force-add anything.

**Setup context:** if setup already ran in this session (`docs/serel-setup.md`, or start's setup mode), treat its answers as given — skip the open prompt when the idea is already described and mark those items clear in Phase 2 — and ask only about what is still missing. The proposal and approval steps below are unchanged.

**Existing bank content:** check each core file in the effective bank. If every one has real content beyond the template placeholders, point the user toward `$start` or planning instead. If only some do (a partial bank, such as a `projectbrief.md` the user wrote), keep those files exactly as they are and treat them as the user's answers: skip the open prompt when they already describe the idea, mark what they cover as clear in Phase 2, and propose only the files that are missing, empty, or template-only.

**Stage:** in the selected scope, if there is meaningful product code — not counting Serel Memory's own files (its workflows, `hooks/`, `bin/serel-memory`, framework docs, bank templates, and the `tests/` and `.github/` a degit copy brings) or code in another scope — recommend `$init-memory` instead (it can read a spec too); if there is a PRD or spec but no code, recommend `$from-prd`. Otherwise, proceed.

## Phase 1 - Open Prompt

Ask:

> Tell me what you want to build. Don't worry about structure - just what's in your head right now. A sentence is fine; a paragraph is fine; a rambling explanation is fine.

Listen to the answer before restructuring it.

## Phase 2 - Map And Ask

Classify these items as clear, partial, or missing:

1. Problem - what pain or opportunity drives this
2. User - who specifically has this need
3. Today's solution - what they do now and why it falls short
4. Success - what "this worked" looks like concretely
5. Minimum scope - smallest useful version
6. Anti-scope - what this explicitly does not do
7. Constraints - time, budget, tech, compliance, anything binding
8. Stack hints - tech they want or have ruled out

Skip clear items. For partial and missing items, ask one targeted question at a time. Aim for 3-5 high-value questions total.

Prefer concrete questions, for example:

- "Is this for you only, for a specific team of 5-50 people, or for thousands of strangers?"
- "Six months from now, if this is working, what would specifically be different?"
- "If you could ship only one feature on day one and skip everything else, which one is it?"

## Phase 3 - Synthesize

Once there is enough material, draft proposals for these files (in a partial bank, only the ones still missing, empty, or template-only):

- `memory-bank/projectbrief.md`
- `memory-bank/productContext.md`
- `memory-bank/systemPatterns.md`
- `memory-bank/techContext.md`
- `memory-bank/decisionLog.md`
- `memory-bank/activeContext.md`
- `memory-bank/progress.md`

Show proposals one file at a time. After each proposal, wait for approval, revision, or pushback before writing.

## Rules

- Do not pretend to know things the user has not said.
- Push back gently when the answer is too vague to create useful memory-bank content.
- Resist adding scope.
- Do not validate or endorse the idea; document and clarify it.
- Use `decisionLog.md` only for explicit decisions made during discovery; otherwise keep it empty/template-light.
- After all approved files are written, end with: **"Memory bank seeded. Use `$start` to verify the bootstrap, or ask me to plan the first chunk of work."**

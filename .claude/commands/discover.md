---
description: Help the user define a project from a rough idea (no code yet); produces initial memory bank
---

# /discover

Use this at the start of a brand-new project, when the user has an idea but hasn't yet articulated it as a brief. You'll guide them through structured discovery, then propose memory bank contents based on the dialogue.

This is the inverse of `/init-memory`. That command analyzes existing code. This one helps shape a project that doesn't exist yet.

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

**Existing bank content:** check each core file in the effective bank. If every one has real content beyond the template placeholders, this is the wrong command — point the user toward `/breakdown` or `/start` instead. If only some do (a partial bank, such as a `projectbrief.md` the user wrote), keep those files exactly as they are and treat them as the user's answers: skip the open prompt when they already describe the idea, mark what they cover as clear in Phase 2, and propose only the files that are missing, empty, or template-only.

**Stage:** in the selected scope, if there is meaningful product code — not counting Serel Memory's own files (its workflows, `hooks/`, `bin/serel-memory`, framework docs, bank templates, and the `tests/` and `.github/` a degit copy brings) or code in another scope — recommend `/init-memory` instead (it can read a spec too); if there is a PRD or spec but no code, recommend `/from-prd`. Otherwise, proceed.

## Phase 1 — Open prompt

Start with this, more or less verbatim:

> "Tell me what you want to build. Don't worry about structure — just what's in your head right now. A sentence is fine; a paragraph is fine; a rambling explanation is fine."

Listen to whatever the user gives. Don't interrupt. Don't restructure. Just take it in.

## Phase 2 — Map and ask

From the user's initial answer, identify which of these are **clear**, **partial**, or **missing**:

1. **Problem** — what pain or opportunity drives this
2. **User** — who specifically has this need
3. **Today's solution** — what they do now and why it falls short
4. **Success** — what "this worked" looks like concretely
5. **Scope (minimum)** — smallest version that would be useful
6. **Anti-scope** — what this explicitly does NOT do
7. **Constraints** — time, budget, tech, compliance, anything binding
8. **Stack hints** — tech they want or have ruled out

Skip CLEAR items. For PARTIAL and MISSING items, ask **one targeted question at a time**. Wait for the answer before asking the next. Aim for 3–5 well-chosen questions total. Not eight.

Good questions are CONCRETE. Examples:

- Bad: "Who's the user?"
- Good: "Is this for you only, for a specific team of 5–50 people, or for thousands of strangers? Each one changes how this would look."

- Bad: "What does success look like?"
- Good: "Six months from now, if this is working, what would specifically be different in your day or in the world?"

- Bad: "What's the scope?"
- Good: "If you could ship only one feature on day one and skip everything else, which one is it?"

## Phase 3 — Synthesize

Once you have enough, draft proposals for these files (in a partial bank, only the ones still missing, empty, or template-only):

- `memory-bank/projectbrief.md` — what, why, success, anti-scope, constraints
- `memory-bank/productContext.md` — user, job, today's solution, UX principles
- `memory-bank/systemPatterns.md` — keep light. Architecture often emerges later. Only capture what the user has clear opinions on.
- `memory-bank/techContext.md` — keep light. Stack often emerges as the project takes shape.
- `memory-bank/decisionLog.md` — only explicit decisions made during discovery; otherwise keep template-light.
- `memory-bank/activeContext.md` — immediate next focus and open questions.
- `memory-bank/progress.md` — planning status and what exists so far.

Show proposals **one file at a time**. After each, wait for the user to approve, revise, or push back before moving to the next.

## Rules

- Don't pretend to know things the user hasn't told you.
- If the user gives a weak answer ("idk, just kind of an AI thing"), push back gently: "I don't have enough yet to write a brief that's actually useful. Can you tell me more about [specific thing]?"
- Resist adding scope. Users usually come in wanting to do too much for v1. Help them carve back to a minimum useful version.
- Don't validate the idea itself. Your job is to help them articulate it, not endorse it.
- Don't synthesize until you have real material. Better to ask one more question than to fabricate.
- After synthesis, the project is still in their hands. You've documented what they said; you haven't blessed it.

## Handoff

When the files are approved and written, end with:

> "Memory bank seeded. Run `/start` to verify the bootstrap, or `/breakdown` if you want to break the first chunk of work into steps."

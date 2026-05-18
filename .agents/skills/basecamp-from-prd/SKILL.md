---
name: basecamp-from-prd
description: "Seed basecamp memory-bank files from an existing PRD, product brief, spec, or requirements document. Use when a new project has a source document but little or no code yet."
---

# Basecamp From PRD

Use this skill when a project has a PRD, product brief, strategy doc, or similar source document, but little or no code yet. This sits between `basecamp-discover` for rough ideas and `basecamp-init-memory` for existing codebases.

## Workflow

1. Determine the PRD path.
   - If the user provided a path, use it.
   - If not, look for likely files in `docs/`, the repo root, or filenames containing `prd`, `brief`, `spec`, `requirements`, or `product`.
   - If there are multiple plausible files, ask which one to use.
2. Read the PRD in full.
3. Check whether the memory bank already has substantive content. If it does, ask whether to merge from the PRD or stop.
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
5. Ask at most 3 targeted follow-up questions for material gaps that would make the memory bank misleading if guessed. Skip questions where `TBD` is acceptable.
6. Propose contents for every memory bank file:
   - `memory-bank/projectbrief.md`
   - `memory-bank/productContext.md`
   - `memory-bank/systemPatterns.md`
   - `memory-bank/techContext.md`
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

After all six proposals, stop and wait. Do not write anything until the user approves or revises.

## Rules

- Treat the PRD as source material, not absolute truth.
- Do not invent details to fill empty sections. Use `<TBD>` or ask.
- Keep `systemPatterns.md` and `techContext.md` light unless the PRD states real technical decisions.
- Use `activeContext.md` to capture the immediate next focus after seeding the bank.
- Use `progress.md` to reflect that the project is initialized/planning unless code already exists.
- Do not overwrite the PRD.
- Do not bloat the bank; preserve signal.

## Handoff

When approved files are written, end with: **"Memory bank seeded from the PRD. Use `$basecamp-start` to verify the bootstrap, or ask me to plan the first implementation chunk."**

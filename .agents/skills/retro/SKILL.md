---
name: retro
description: "Run a sprint or weekly retrospective from the memory bank and git activity. Use when the user asks for a retro, retrospective, post-mortem, or wants to reflect on what shipped, stalled, or surprised."
---

# Retro

Run a retrospective on the last sprint, week, or whatever timeframe makes sense for this project. Pull from the memory bank and git activity so the conversation starts from facts, not vibes.

**Effective bank:** if `memory-bank.local/` exists (upstream Serel Memory development only), all memory-bank and `.rules` reads and writes below target it instead of the tracked templates. See "Resolving the effective bank" in `docs/workflow-contract.md`.

**Scope:** resolve which bank this targets per "Resolving scope" in `docs/workflow-contract.md` — an optional `--scope <path>` argument selects a project bank when the repo configures `scopes`; otherwise the root bank, as always.

## Workflow

1. Ask the user for the timeframe if it's not obvious: "Retro on the last week, the last sprint, since the last retro? Default: last 7 days."
2. Read:
   - `memory-bank/activeContext.md` — current focus and recent changes
   - `memory-bank/progress.md` — status snapshot
3. Run `git log --since="<timeframe>" --oneline --all` to see what was done.
4. If a `docs/retros/` directory exists, read the most recent retro for continuity (commitments made last time, recurring themes).

## Output

Produce a retro in this structure:

```text
# Retro — [timeframe]

## What we shipped
- [item] — [why it matters]
- [item]

## What stalled or didn't ship
- [item] — [why it didn't move]
- [item]

## What surprised us
- [unexpected thing — either good or bad]

## What we'd do differently
- [concrete change for next cycle]

## Themes
- [pattern across items above — e.g., "scope creep on every feature," "external blockers eating velocity"]

## Action items
- [ ] [specific thing to do, with owner if known]
- [ ] [specific thing]

## Commitments from last retro (if applicable)
- [what we said we'd do] — [did we do it?]
```

Save to `docs/retros/YYYY-MM-DD.md`. Create the directory if it doesn't exist.

## Rules

- Be specific. "Communication was bad" is useless. "We didn't surface the API rate limit until day 4 of the sprint" is a retro entry.
- Don't sugarcoat. The point of a retro is to learn; soft language hides the lessons.
- Action items need owners and concrete next steps, not "we should think about X."
- If last retro's commitments weren't met, note it. Patterns matter more than single misses.

After writing, ask the user if they want any items elevated to `.rules` as durable learnings worth carrying across all future retros. For a learning that is already in `.rules` or repeats a past retro, ask why the guidance did not take and propose a test or hook check instead of another line.

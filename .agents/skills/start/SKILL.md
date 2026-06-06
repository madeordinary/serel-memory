---
name: start
description: "Start or resume a memory-bank project in Codex. Use: $start (quick) or $start full (rich dashboard). Loads memory bank, summarizes state, asks where to pick up."
---

# Start

Use this skill to orient a Codex session around the basecamp memory bank.

**Mode:** Check the arguments passed to this skill.

- If empty, `quick`, or `brief` → use **Quick mode** (compact summary, saves tokens).
- If `full`, `onboard`, or `dashboard` → use **Full mode** (rich onboarding dashboard).

## Step 1 — Read the memory bank (both modes)

1. Read every file in `memory-bank/` in this order:
   - `projectbrief.md`
   - `productContext.md`
   - `systemPatterns.md`
   - `techContext.md`
   - `decisionLog.md`
   - `activeContext.md`
   - `progress.md`
2. Read `.rules`.
3. Look for optional docs under `memory-bank/` that clearly match the user's task or active context, and read only the relevant ones.
4. Run `git log --oneline -10`.
5. Run `git status`.

If any memory bank file is missing, empty, or still only template placeholders, mark it as `BLANK` or `UNINITIALIZED` and ask whether to initialize it before proceeding.

## Step 2 — Produce the output

### Quick mode (default)

Produce a context audit and summary:

```text
CONTEXT AUDIT:
- Read: [memory-bank files and .rules]
- Optional docs read: [paths or "(none)"]
- Uninitialized: [missing, empty, or template-only files]
- Recent commits not reflected in memory: [yes/no/unknown]
- Working tree: [clean / dirty summary]

PROJECT: [one sentence - what we're building]
PHASE: [from progress.md]
LAST SESSION: [from activeContext.md - what was being worked on]
CURRENT STATE: [what works / what's in progress / known issues - 2 lines max]
NEXT STEPS: [from activeContext.md - top 1-3]
OPEN QUESTIONS: [anything blocking or unresolved]
```

End with: **"Where do you want to pick up?"** Then wait.

### Full mode (`$start full`)

Produce the full context audit (same as quick mode), then continue with all sections below.

#### Recent Progress (last 2-3 sessions)

Extract from `progress.md` recent milestones and `activeContext.md` recent changes:

- Session achievements with dates
- Key technical discoveries or architectural changes
- Milestones reached

#### Current State Analysis

**What Works**

- Pull from `progress.md` "What works" section - list each capability

**In Progress**

- Pull from `progress.md` "In progress" section
- Cross-reference with `activeContext.md` current focus

**Known Issues**

- Pull from `progress.md` "Known issues" section

**What's Left to Build**

- Pull from `progress.md` "What's left to build" section
- Include estimates where you can reasonably infer them

#### Open Decisions & Blockers

- Pull from `activeContext.md` open questions
- Pull from `decisionLog.md` any pending/draft decisions
- Flag any memory bank staleness (commits not reflected, files out of date)

#### Git Status

- Uncommitted changes that should be addressed
- Commits ahead/behind of remote
- Current branch info

#### Suggested Next Steps

Provide 3-5 specific, actionable recommendations organized by urgency:

🔴 **URGENT** — blocking progress or stale/broken
🟡 **HIGH-VALUE** — best use of this session based on momentum and impact
🟢 **STRATEGIC** — important but can wait

For each, include: clear action item, rough time estimate, expected outcome.

#### Direction Options

Present 3-4 options clearly:

- **Option A:** Continue recent momentum — [describe based on activeContext]
- **Option B:** Address top priority — [from what's left to build]
- **Option C:** Start next feature/initiative — [from what's left or open questions]
- **Option D:** Something else

End with: **"Which direction would you like to take for this session?"** Then wait.

---

Do not start working on anything until the user answers.

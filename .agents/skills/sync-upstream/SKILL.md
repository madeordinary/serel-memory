---
name: sync-upstream
description: "Check the upstream basecamp repo for framework updates (skills, commands, agent instructions) and selectively pull changes. Use when the user asks to update basecamp, check for upstream changes, sync the framework, or pull latest skills."
---

# Sync Upstream

Check the upstream basecamp repo for new framework updates and help the user decide what to pull.

## Preconditions

- Git must be available.
- The repo must have been originally cloned or forked from the basecamp template.

## Framework vs Project Files

Only sync framework files. Never auto-merge project-specific files.

**Framework files** (safe to sync):
- `.agents/skills/` — Codex skill definitions
- `.claude/commands/` — Claude Code slash commands
- `AGENTS.md`, `CLAUDE.md` — agent instructions
- `docs/workflow-contract.md`, `docs/cross-agent-review.md` — framework docs
- `hooks/` — optional automation scripts

**Project files** (never sync):
- `memory-bank/` — user's actual project context
- `.rules` — project-specific patterns
- `docs/decisions/` — project-specific ADRs
- `docs/` files not in the framework list above
- Application code, configs, project-specific docs

## Framework file allowlist

Use this exact list in all git commands:

```
.agents/skills/ .claude/commands/ AGENTS.md CLAUDE.md docs/workflow-contract.md docs/cross-agent-review.md hooks/
```

## Workflow

1. **Preflight: require a clean worktree** for framework files. If any have uncommitted changes, warn and ask the user to commit or stash first.

2. **Verify upstream remote exists.** If missing, add it:
   ```bash
   git remote add upstream https://github.com/gusfeliciano/basecamp.git
   ```
   If the user forked from a different origin, ask for the correct URL.

3. **Fetch upstream without merging:**
   ```bash
   git fetch upstream main
   ```

4. **Detect sync mode:**
   ```bash
   git merge-base HEAD upstream/main 2>/dev/null
   ```
   - Merge base exists: **fork mode** — use three-dot diffs.
   - No merge base (unrelated histories, e.g. `degit`): **template mode** — compare files directly, require user review for every change.

5. **Diff only framework files** using the allowlist.

6. **Flag conflict risks** (fork mode: files changed on both sides; template mode: treat every locally modified file as a conflict).

7. **Present a summary:**
   ```text
   UPSTREAM SYNC CHECK
   Mode: [fork / template (no shared history)]

   New upstream commits: [count]
   Framework files changed: [list]

   CONFLICT RISK: [files changed on both sides]
   SAFE TO PULL: [files only changed upstream]
   NEW FILES: [files that don't exist locally]
   ```

8. **Let the user choose:**
   - Pull all safe changes
   - View specific diffs first
   - Apply file-by-file (show diff, accept or skip each)
   - Skip

   Do not offer cherry-pick by commit — upstream commits may touch both framework and project files.

9. **Execute** using `git restore --source=upstream/main -- <path>` for safe files. For conflicting files, show the diff and let the user decide per-file.

10. **After syncing**, suggest running `$update-memory` if significant framework changes were pulled.

## If no upstream changes

Report that the project is up to date and note when the last sync check was done (from the upstream fetch timestamp).

## Fallback

If `upstream` points to a repo that doesn't exist or can't be reached, report the error clearly and suggest the user verify the upstream URL with `git remote -v`.

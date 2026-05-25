---
description: Check the upstream basecamp repo for updates and selectively pull changes
---

# /sync-upstream

Check the upstream basecamp repo for new framework updates (skills, commands, agent instructions) and help the user decide what to pull into their project.

## Preconditions

- Git must be available.
- The repo must have been originally cloned or forked from the basecamp template.

## Framework vs Project Files

Only framework files should be synced. Never auto-merge project-specific files.

**Framework files** (safe to sync):
- `.agents/skills/` — Codex skill definitions
- `.claude/commands/` — Claude Code slash commands
- `AGENTS.md` — agent instructions
- `CLAUDE.md` — top-level Claude Code config
- `docs/workflow-contract.md` — workflow design contract
- `docs/cross-agent-review.md` — second-opinion loop policy
- `hooks/` — optional automation scripts

**Project files** (never sync):
- `memory-bank/` — user's actual project context
- `.rules` — project-specific patterns
- `docs/decisions/` — project-specific ADRs
- `docs/` files not in the framework list above (PRDs, specs, project docs)
- Any application code, configs, or project-specific docs

## Framework file allowlist

Only these paths are eligible for sync. Use this exact list in all git commands:

```
.agents/skills/ .claude/commands/ AGENTS.md CLAUDE.md docs/workflow-contract.md docs/cross-agent-review.md hooks/
```

## Workflow

1. **Preflight: require a clean worktree.**

   ```bash
   git status --porcelain -- .agents/skills/ .claude/commands/ AGENTS.md CLAUDE.md docs/workflow-contract.md docs/cross-agent-review.md hooks/
   ```

   If any framework files have uncommitted changes, warn the user and ask them to commit or stash before syncing. `git restore` from upstream would silently overwrite their edits.

2. **Check for upstream remote.**

   ```bash
   git remote get-url upstream 2>/dev/null
   ```

   If missing, add it:

   ```bash
   git remote add upstream https://github.com/gusfeliciano/basecamp.git
   ```

   If the user forked from a different basecamp origin, ask them for the correct URL.

3. **Fetch upstream without merging.**

   ```bash
   git fetch upstream main
   ```

4. **Detect sync mode.**

   ```bash
   git merge-base HEAD upstream/main 2>/dev/null
   ```

   - If a merge base exists: **fork mode** — use three-dot diffs and conflict detection.
   - If no merge base (unrelated histories, e.g. `degit` installs): **template mode** — compare files directly. Every changed file requires the user to review its diff before applying.

5. **Show what changed since last sync.**

   **Fork mode:**
   ```bash
   git diff HEAD...upstream/main --stat -- <allowlist>
   ```

   **Template mode:**
   ```bash
   git diff HEAD upstream/main --stat -- <allowlist>
   ```

6. **Flag conflict risks (fork mode only).**

   ```bash
   BASE=$(git merge-base HEAD upstream/main)
   comm -12 \
     <(git diff --name-only "$BASE" HEAD -- <allowlist> | sort) \
     <(git diff --name-only "$BASE" upstream/main -- <allowlist> | sort)
   ```

   In template mode, treat every locally modified file as a conflict risk.

7. **Present a summary.**

   ```text
   UPSTREAM SYNC CHECK
   Mode: [fork / template (no shared history)]
   
   New upstream commits: [count]
   Framework files changed: [list with +/- line counts]
   
   CONFLICT RISK:
   - [files changed on both sides, if any]
   
   SAFE TO PULL:
   - [files only changed upstream]
   
   NEW FILES:
   - [files that don't exist locally yet]
   ```

8. **Offer options.** Let the user choose:

   - **Pull all safe changes** — apply only files with no local modifications
   - **View specific diffs** — show full diff for files the user wants to inspect
   - **Apply file-by-file** — show diff for each changed file, let user accept or skip
   - **Skip** — do nothing, just note the available updates

   Do not offer cherry-pick by commit — upstream commits may touch both framework and project files.

9. **Execute the chosen strategy.**

   For safe files, use restore from upstream:
   ```bash
   git restore --source=upstream/main -- <file-path>
   ```

   For conflicting files, show the diff and let the user decide per-file.

   For new files (skills/commands that don't exist locally), restore them in:
   ```bash
   git restore --source=upstream/main -- <new-file-path>
   ```

10. **After syncing, summarize what was pulled** and suggest the user run `/update-memory` if significant changes were made to framework behavior.

## If no upstream changes

Report that the project is up to date and show when the last sync check was done (from the upstream fetch timestamp).

## Fallback

If `upstream` points to a repo that doesn't exist or can't be reached, report the error clearly and suggest the user verify the upstream URL with `git remote -v`.

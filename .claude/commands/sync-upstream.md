---
description: Check the upstream Serel Memory repo for updates and selectively pull changes
---

# /sync-upstream

Check the upstream Serel Memory repo for new framework updates (skills, commands, agent instructions) and help the user decide what to pull into their project.

## Preconditions

- Git must be available.
- The repo must have started from Serel Memory (formerly Basecamp) — copied in via `degit`, cloned, or forked. (Template mode in step 4 handles the `degit` case, where there's no shared git history.)

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
- `.serel-memory.json` — this project's provenance anchor (per-project state, see below)
- `docs/decisions/` — project-specific ADRs
- `docs/` files not in the framework list above (PRDs, specs, project docs)
- Any application code, configs, or project-specific docs

## The provenance anchor (`.serel-memory.json`)

A small file at the project root recording which upstream version this project was
scaffolded from or last synced to:

```json
{ "upstream": "madeordinary/serel-memory", "ref": "v0.3.0", "linked": false }
```

- `ref` — the upstream tag or commit this project is anchored to.
- `linked: true` — the anchor was reconstructed after install (exact starting
  version unknown), so diffs against `ref` may include changes the project
  already has. Treat them as candidates to review, not guaranteed-new.

The anchor makes template-mode reports precise: instead of diffing every file
blindly, you can show exactly what changed upstream since `ref`.

`.serel-memory.json` is the single provenance-anchor filename as of Serel
Memory 0.3.0. Never create a second anchor file; two mutable anchors could
disagree. A legacy `.basecamp.json` left over from a v0.x install is never
read — it triggers the fail-fast guard in step 1 until the user renames it.

## Framework file allowlist

Only these paths are eligible for sync. Use this exact list in all git commands:

```text
.agents/skills/ .claude/commands/ AGENTS.md CLAUDE.md docs/workflow-contract.md docs/cross-agent-review.md hooks/
```

## Workflow

1. **Preflight: require a clean worktree, and read the anchor.**

   ```bash
   git status --porcelain -- .agents/skills/ .claude/commands/ AGENTS.md CLAUDE.md docs/workflow-contract.md docs/cross-agent-review.md hooks/
   # Legacy-anchor guard: fail fast, never treat as unanchored, never reconstruct.
   if [ ! -f .serel-memory.json ] && [ -f .basecamp.json ]; then  # legacy anchor present
     echo "MIGRATION REQUIRED: this project still has a legacy .basecamp.json anchor."
     echo "Rename it to .serel-memory.json (same JSON schema) before syncing — Serel Memory 0.3.0 ended the v0.x anchor name."
     exit 1
   fi
   cat .serel-memory.json 2>/dev/null
   ```

   If any framework files have uncommitted changes, warn the user and ask them to commit or stash before syncing. `git restore` from upstream would silently overwrite their edits.

   **Fail fast on a legacy-only anchor.** If the guard above fired, STOP: the project is still anchored to a pre-0.3.0 install. Tell the user to migrate by renaming the legacy `.basecamp.json` to `.serel-memory.json` (same schema; advance `ref` on the next successful sync). Never treat the project as unanchored and never reconstruct a baseline while a legacy `.basecamp.json` is present — and never create a second anchor alongside it.

   Note the anchor's `ref` and `linked` values if the file exists; if it doesn't, you'll offer to reconstruct it in step 5.

2. **Check for upstream remote.**

   ```bash
   git remote get-url upstream 2>/dev/null
   ```

   If missing, add it using the anchor's `upstream` value (fall back to `madeordinary/serel-memory` when there's no anchor):

   ```bash
   git remote add upstream "https://github.com/<anchor-upstream>.git"
   ```

   If the remote and the anchor disagree about the upstream slug, surface the
   mismatch and ask the user which is correct before proceeding. If the user
   forked from a different origin, ask them for the correct URL.

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

   **Template mode with an anchor:** if `.serel-memory.json` has a `ref` that resolves in the fetched upstream history (`git rev-parse --verify "<ref>^{commit}"` after the fetch), also show what actually changed upstream since the anchor — this is the precise report:

   ```bash
   git log --oneline "<ref>"..upstream/main -- <allowlist>
   git diff "<ref>" upstream/main --stat -- <allowlist>
   ```

   Keep using the direct `HEAD`-vs-`upstream/main` file diff for conflict detection (the project's local edits aren't in upstream history). If the anchor has `"linked": true`, remind the user that anchor-based diffs may include changes their copy already has.

   **No anchor?** Offer to reconstruct one now, marked as linked. Derive `upstream` from the actual remote — don't hardcode it:

   ```bash
   UP="$(git remote get-url upstream | sed -E 's#^(git@github\.com:|https://github\.com/)##; s#\.git$##')"
   printf '{ "upstream": "%s", "ref": "%s", "linked": true }\n' "$UP" "$(git rev-parse upstream/main)" > .serel-memory.json
   ```

   Explain what `linked: true` means: the exact version this project started from is unknown, so this anchor only establishes a baseline from today forward.

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

9. **Execute the chosen strategy.** Restore **individual files** from the upstream-changed list — never a whole allowlisted directory (e.g. `git restore --source=upstream/main -- .claude/commands/`), which would also delete any custom commands or skills the downstream project added. The directory allowlist is for diff *discovery*, not for restore.

   For safe files, use restore from upstream:

   ```bash
   git restore --source=upstream/main -- <file-path>
   ```

   For conflicting files, show the diff and let the user decide per-file.

   For new files (skills/commands that don't exist locally), restore them in:

   ```bash
   git restore --source=upstream/main -- <new-file-path>
   ```

10. **After syncing, update the anchor and summarize.** Advance `.serel-memory.json` to the upstream commit you just synced from, so the next sync reports only what's newer (derive `upstream` from the remote as in step 5):

    ```bash
    printf '{ "upstream": "%s", "ref": "%s", "linked": false }\n' "$UP" "$(git rev-parse upstream/main)" > .serel-memory.json
    ```

    (After a reviewed sync the baseline is now known, so `linked` becomes `false`
    even if the anchor was originally reconstructed.)

    If the user **skipped** some upstream changes, tell them before advancing: once the anchor moves, skipped changes stop appearing in the "new since last sync" report (they still show up in the file-level diff against `upstream/main`). Let them choose: advance the anchor anyway (skip means "no thanks"), or keep the old anchor (skip means "not yet").

    Then summarize what was pulled and suggest the user run `/update-memory` if significant changes were made to framework behavior.

## If no upstream changes

Report that the project is up to date and show when the last sync check was done (from the upstream fetch timestamp).

## Fallback

If `upstream` points to a repo that doesn't exist or can't be reached, report the
error clearly, suggest the user verify it with `git remote -v`, and mention the
canonical URL `https://github.com/madeordinary/serel-memory.git`.

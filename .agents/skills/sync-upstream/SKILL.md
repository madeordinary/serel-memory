---
name: sync-upstream
description: "Check the upstream Serel Memory repo for framework updates (skills, commands, agent instructions) and selectively pull changes. Use when the user asks to update Serel Memory, update Basecamp, check for upstream changes, sync the framework, or pull latest skills."
---

# Sync Upstream

Check the upstream Serel Memory repo for new framework updates and help the user decide what to pull.

## Preconditions

- Git must be available.
- The repo must have started from Serel Memory (formerly Basecamp) — copied in via `degit`, cloned, or forked. (Template mode in step 4 handles the `degit` case, where there's no shared git history.)

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
- `.basecamp.json` — this project's provenance anchor (per-project state, see below)
- `docs/decisions/` — project-specific ADRs
- `docs/` files not in the framework list above
- Application code, configs, project-specific docs

## The provenance anchor (`.basecamp.json`)

A small file at the project root recording which upstream version this project was
scaffolded from or last synced to:

```json
{ "upstream": "madeordinary/serel-memory", "ref": "v0.1.0", "linked": false }
```

- `ref` — the upstream tag or commit this project is anchored to.
- `linked: true` — the anchor was reconstructed after install (exact starting
  version unknown), so diffs against `ref` may include changes the project
  already has. Treat them as candidates to review, not guaranteed-new.

The anchor makes template-mode reports precise: instead of diffing every file
blindly, you can show exactly what changed upstream since `ref`.

The Basecamp-era `.basecamp.json` name remains the single provenance-anchor
filename for every v0.x release. Do not create a second
`.serel-memory.json`; two mutable anchors could disagree.

## Framework file allowlist

Use this exact list in all git commands:

```text
.agents/skills/ .claude/commands/ AGENTS.md CLAUDE.md docs/workflow-contract.md docs/cross-agent-review.md hooks/
```

## Workflow

1. **Preflight: require a clean worktree** for framework files. If any have uncommitted changes, warn and ask the user to commit or stash first. Also read the anchor (`cat .basecamp.json 2>/dev/null`) — note its `ref` and `linked` values; if missing, offer to reconstruct it in step 5.

2. **Verify upstream remote exists.** If missing, add it using the anchor's `upstream` value (fall back to `madeordinary/serel-memory` when there's no anchor):

   ```bash
   git remote add upstream "https://github.com/<anchor-upstream>.git"
   ```

   During v0.x, treat `gusfeliciano/basecamp` and
   `madeordinary/serel-memory` as the same upstream. An old anchor or remote may
   continue fetching through GitHub's redirect; do not stop on that one known
   mismatch. After a successful fetch, offer to normalize an old remote with
   `git remote set-url upstream https://github.com/madeordinary/serel-memory.git`.
   For every other mismatch, surface it and ask which is correct before
   proceeding. If the user forked from a different origin, ask for the correct
   URL.

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

   **Template mode with an anchor:** if the anchor's `ref` resolves in the fetched upstream history (`git rev-parse --verify "<ref>^{commit}"`), also show the precise what's-new report:

   ```bash
   git log --oneline "<ref>"..upstream/main -- <allowlist>
   git diff "<ref>" upstream/main --stat -- <allowlist>
   ```

   Keep the direct `HEAD`-vs-`upstream/main` file diff for conflict detection. If `"linked": true`, remind the user anchor-based diffs may include changes their copy already has.

   **No anchor?** Offer to reconstruct one, marked as linked (baseline starts today; exact original version unknown). Derive `upstream` from the actual remote — don't hardcode it:

   ```bash
   UP="$(git remote get-url upstream | sed -E 's#^(git@github\.com:|https://github\.com/)##; s#\.git$##')"
   if [ "$UP" = "gusfeliciano/basecamp" ]; then UP="madeordinary/serel-memory"; fi
   printf '{ "upstream": "%s", "ref": "%s", "linked": true }\n' "$UP" "$(git rev-parse upstream/main)" > .basecamp.json
   ```

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

9. **Execute** using `git restore --source=upstream/main -- <path>` for safe files, **one file at a time** from the upstream-changed list — never a whole allowlisted directory, which would delete any custom commands/skills the project added. The directory allowlist is for diff discovery, not restore. For conflicting files, show the diff and let the user decide per-file.

10. **After syncing, update the anchor**, then summarize (derive `upstream` from the remote as in step 5):

    ```bash
    printf '{ "upstream": "%s", "ref": "%s", "linked": false }\n' "$UP" "$(git rev-parse upstream/main)" > .basecamp.json
    ```

    (After a reviewed sync the baseline is known, so `linked` becomes `false`.
    Normalize the known legacy slug to `madeordinary/serel-memory` before
    writing, as in step 5.) If the user skipped some changes, warn before
    advancing: skipped changes stop appearing in the "new since last sync"
    report once the anchor moves (they still show in the file-level diff) — let
    them choose to advance or keep the old anchor. Suggest running
    `$update-memory` if significant framework changes were pulled.

## If no upstream changes

Report that the project is up to date and note when the last sync check was done (from the upstream fetch timestamp).

## Fallback

If `upstream` points to a repo that doesn't exist or can't be reached, report the
error clearly, suggest the user verify it with `git remote -v`, and mention the
canonical URL `https://github.com/madeordinary/serel-memory.git`.

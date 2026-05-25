# Active Context

> The most volatile file in the bank. Current focus, recent moves, next steps.
> Update at the end of every working session.

## Current focus

Basecamp framework is at full skill parity (17/17). Exploring automatic cross-agent review during planning.

## Recent changes

- Added Codex skills for retro, weekly-update, runbook, and security-check — full 17/17 parity
- Dropped `basecamp-` prefix from all Codex skills to match slash command naming
- Added `/sync-upstream` command and `$sync-upstream` Codex skill for framework updates
- Renamed `/plan` to `/breakdown` to avoid Claude Code plan mode conflict
- Added cross-agent second opinion workflow (`/ask-codex` / `$ask-claude`)

## Next steps

1. Consider reorganizing `docs/` so framework docs live under a dedicated path (Codex raised this)
2. Test `/sync-upstream` on a real downstream fork
3. Explore automatic cross-agent review during planning workflows

## Open questions

- Should `AGENTS.md` and `CLAUDE.md` always require manual diff review during sync? (users are expected to customize these)
- Should `README.md`, `.gitignore`, and `LICENSE` be sync-upstream framework files, or project-owned after installation?

## Notes for next session

- The `/ask-codex` → `$ask-claude` naming asymmetry is intentional and documented in decisionLog.md as an explicit parity exception.
- The sync-upstream command has two modes: fork mode (shared git history) and template mode (degit/unrelated history).

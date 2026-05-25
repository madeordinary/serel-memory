# Active Context

> The most volatile file in the bank. Current focus, recent moves, next steps.
> Update at the end of every working session.

## Current focus

Basecamp framework is at full skill parity (17/17) with mandatory cross-agent planning review.

## Recent changes

- Made cross-agent review mandatory in AGENTS.md and breakdown workflows
- Fixed Codex review findings (stale context, wrong dates, description wording, rsync missing docs/)
- Added Codex skills for retro, weekly-update, runbook, and security-check — full 17/17 parity
- Dropped `basecamp-` prefix from all Codex skills to match slash command naming
- Added `/sync-upstream` command and `$sync-upstream` Codex skill for framework updates

## Next steps

1. Consider reorganizing `docs/` so framework docs live under a dedicated path (Codex raised this)
2. Test `/sync-upstream` on a real downstream fork

## Open questions

- Should `AGENTS.md` and `CLAUDE.md` always require manual diff review during sync? (users are expected to customize these)
- Should `README.md`, `.gitignore`, and `LICENSE` be sync-upstream framework files, or project-owned after installation?

## Notes for next session

- Cross-agent planning review is now a ground rule in AGENTS.md, not just in `/breakdown`. Any non-trivial plan should go through the other CLI.
- Codex did two full repo reviews this session. The second one was clean except for memory bank staleness (now fixed).

# Security Policy

Serel Memory is a kit of markdown files plus a few optional bash hooks. It has no server and no runtime dependencies, and the only network access it triggers is the git operations you explicitly run (e.g. `sync-upstream`'s `git fetch upstream`) — so its attack surface is small. The two things worth being careful about:

## What to watch

- **Optional hooks run shell.** `hooks/session-start.sh` and `hooks/pre-compact.sh` execute in your shell when enabled. Read them before enabling (`bash hooks/enable-hooks.sh`); they're short on purpose. They are off by default.
- **Cross-agent review shells out to another CLI.** Workflows like `/ask-codex` and `/breakdown` can pipe a plan to `codex` or `claude`. **Never put secrets, credentials, private production data, or sensitive customer data into those prompts.** `docs/cross-agent-review.md` states this as policy; treat it as a hard rule.

## Reporting a vulnerability

If you find a security issue in the framework (e.g. a hook that could be coerced into running untrusted input), please report it privately rather than opening a public issue:

- Use GitHub's **private vulnerability reporting** (Security → "Report a vulnerability") if it's enabled on the repository, or
- Open a minimal public issue that says only "security report — please enable private reporting" without details, and the maintainer will follow up privately.

<!-- Maintainer: add a contact email here if you prefer one over GitHub private reporting. -->

We'll acknowledge within a reasonable window and credit reporters who want it.

## Supported versions

Serel Memory is pre-1.0. Security fixes land on `main` and in the next tagged release.

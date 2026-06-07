#!/usr/bin/env bash
# Asserts Claude command <-> Codex skill parity.
# Every workflow must ship both adapters: a .claude/commands/<name>.md slash
# command and a .agents/skills/<name>/ skill (SKILL.md + agents/openai.yaml).
# The single intentional asymmetry is the cross-agent helper, which names the
# OTHER agent on each side: /ask-codex (Claude) <-> $ask-claude (Codex).
set -euo pipefail
cd "$(dirname "$0")/.."

fail=0

# command name -> expected skill name
map_cmd() { case "$1" in ask-codex) echo "ask-claude" ;; *) echo "$1" ;; esac; }
# skill name -> expected command name
map_skill() { case "$1" in ask-claude) echo "ask-codex" ;; *) echo "$1" ;; esac; }

cmd_count=0
for f in .claude/commands/*.md; do
  c="$(basename "$f" .md)"
  cmd_count=$((cmd_count + 1))
  s="$(map_cmd "$c")"
  if [ ! -f ".agents/skills/$s/SKILL.md" ]; then
    echo "MISSING SKILL: command /$c has no .agents/skills/$s/SKILL.md"; fail=1
  fi
  if [ ! -f ".agents/skills/$s/agents/openai.yaml" ]; then
    echo "MISSING MANIFEST: skill \$$s has no agents/openai.yaml"; fail=1
  fi
done

skill_count=0
for d in .agents/skills/*/; do
  s="$(basename "$d")"
  skill_count=$((skill_count + 1))
  c="$(map_skill "$s")"
  if [ ! -f ".claude/commands/$c.md" ]; then
    echo "MISSING COMMAND: skill \$$s has no .claude/commands/$c.md"; fail=1
  fi
done

# Cross-agent behavior parity: if one adapter shells out to the other CLI,
# its pair must do the symmetric call. A Claude command invoking `codex exec`
# pairs with a Codex skill invoking `claude -p`, and vice versa — otherwise
# the dual-CLI behavior silently exists on one side only. Each side must also
# never invoke its OWN CLI (the telltale of a partially swapped mirror).
xagent_pairs=0
for f in .claude/commands/*.md; do
  c="$(basename "$f" .md)"
  s="$(map_cmd "$c")"
  skill=".agents/skills/$s/SKILL.md"
  [ -f "$skill" ] || continue
  cmd_has="$(grep -c 'codex exec' "$f" || true)"
  skill_has="$(grep -c 'claude -p' "$skill" || true)"
  if [ "$cmd_has" -gt 0 ] && [ "$skill_has" -eq 0 ]; then
    echo "XAGENT DRIFT: /$c mentions codex exec but \$$s never mentions claude -p"; fail=1
  fi
  if [ "$skill_has" -gt 0 ] && [ "$cmd_has" -eq 0 ]; then
    echo "XAGENT DRIFT: \$$s mentions claude -p but /$c never mentions codex exec"; fail=1
  fi
  if [ "$cmd_has" -gt 0 ] && [ "$skill_has" -gt 0 ]; then
    xagent_pairs=$((xagent_pairs + 1))
  fi
  if grep -q 'claude -p' "$f"; then
    echo "XAGENT DRIFT: /$c mentions claude -p (its own CLI) — unswapped mirror?"; fail=1
  fi
  if grep -q 'codex exec' "$skill"; then
    echo "XAGENT DRIFT: \$$s mentions codex exec (its own CLI) — unswapped mirror?"; fail=1
  fi
done

# Read-only + stdin invariants: any flagged secondary-CLI invocation must be
# read-only AND take its prompt via stdin from a file — never inline (long
# inline prompts hang codex exec). Bare prose mentions (no flags) are ignored;
# `codex exec --help` (preflight) is exempt.
if grep -rn 'codex exec --' .claude/commands .agents/skills AGENTS.md docs/cross-agent-review.md \
   | grep -v 'codex exec --help' | grep -v -- '--sandbox read-only -'; then
  echo "INVOCATION DRIFT: codex exec must use '--sandbox read-only -' with a file-piped prompt (lines above)"; fail=1
fi
if grep -rn 'claude -p' .claude/commands .agents/skills AGENTS.md docs/cross-agent-review.md \
   | grep -vE -- '--permission-mode plan *<'; then
  echo "INVOCATION DRIFT: claude -p must use '--permission-mode plan < file' (lines above)"; fail=1
fi

# Belt-and-braces: the historical inline '"<prompt>"' form must never return.
if grep -rnE '(codex exec|claude -p).*"<' .claude/commands .agents/skills AGENTS.md docs/cross-agent-review.md; then
  echo "INLINE PROMPT: cross-agent invocation passes the prompt inline (lines above) — use the temp-file stdin form"; fail=1
fi

if [ "$fail" -eq 0 ]; then
  echo "parity OK: $cmd_count commands <-> $skill_count skills (all paired, manifests present, $xagent_pairs cross-agent pairs symmetric, invocations read-only + file-piped)"
fi
exit "$fail"

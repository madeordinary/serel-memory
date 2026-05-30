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

if [ "$fail" -eq 0 ]; then
  echo "parity OK: $cmd_count commands <-> $skill_count skills (all paired, manifests present)"
fi
exit "$fail"

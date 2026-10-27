#!/usr/bin/env bash
# One source per workflow. Each workflow's source is
# .agents/skills/<name>/SKILL.md, with its resources (agents/openai.yaml and
# any others) in that folder; Codex discovers it there. Claude Code discovers
# .claude/skills/<name>/SKILL.md, a byte-identical copy that sits alone in its
# folder. The single intentional asymmetry is the hand-maintained cross-agent
# helper, which names the OTHER agent on each side: ask-codex (Claude only,
# .claude/skills/ask-codex/) and ask-claude (Codex only, .agents/skills/ask-claude/).
#
# usage: bash tests/check-single-source.sh [--write]
#   --write  first refresh every Claude copy from its source and print each
#            copy it changed, then run the checks. It never deletes anything
#            and never touches the ask pair.
set -euo pipefail
cd "$(dirname "$0")/.."

write=0
case "$#:${1:-}" in
  0:) ;;
  1:--write) write=1 ;;
  *) echo "usage: bash tests/check-single-source.sh [--write]" >&2; exit 2 ;;
esac

fail=0
SRC=.agents/skills
DST=.claude/skills
CLAUDE_ONLY=ask-codex # in $DST only
CODEX_ONLY=ask-claude # in $SRC only

# Own-CLI rule for shared bodies. A body both CLIs load may call the other
# CLI only inside an explicit branch: a line containing "Which CLI am I
# running in", then labeled blocks whose first words (after any list marker
# or indentation) are exactly **In Claude Code:** or **In Codex:**. Every
# `codex exec` must sit under **In Claude Code:** and every `claude -p` under
# **In Codex:**, after the label and before the next label or Markdown
# heading. A `#` line inside a fenced block is code, not a heading. Prints
# one file:line finding per offending line; prints nothing when it passes.
own_cli_rule() {
  awk '
    function fence_mark(s) { match(s, /^[[:space:]]*(```+|~~~+)/); s = substr(s, RSTART, RLENGTH); gsub(/[[:space:]]/, "", s); return s }
    function check(needle, want, wanted,   why) {
      if (index($0, needle) == 0 || label == want) return
      if (label == "early") why = "its label at line " label_at " comes before any \"Which CLI am I running in\" line"
      else if (label != "") why = "self-call: it sits under the **In " (label == "claude" ? "Claude Code" : "Codex") ":** label at line " label_at ", and a CLI must never call itself"
      else if (reset_at > 0) why = "the heading at line " reset_at " ended the labeled block above it"
      else why = "unlabeled: it is not under an **In " wanted ":** label"
      printf "%s:%d: `%s`: %s\n", FILENAME, FNR, needle, why
    }
    FNR == 1 { asked = 0; label = ""; label_at = 0; reset_at = 0; fence = "" }
    {
      if (fence != "") {
        if ($0 ~ /^[[:space:]]*(```|~~~)/) {
          m = fence_mark($0)
          if (substr(m, 1, 1) == substr(fence, 1, 1) && length(m) >= length(fence)) fence = ""
        }
      } else if ($0 ~ /^[[:space:]]*(```|~~~)/) {
        fence = fence_mark($0)
      } else {
        if ($0 ~ /^ ? ? ?#+([[:space:]]|$)/) { if (label != "") reset_at = FNR; label = "" }
        if (index($0, "Which CLI am I running in")) asked = 1
        if ($0 ~ /^[[:space:]]*(([-+*]|[0-9]+[.)])[[:space:]]+)?\*\*In Claude Code:\*\*/) { label = asked ? "claude" : "early"; label_at = FNR; reset_at = 0 }
        else if ($0 ~ /^[[:space:]]*(([-+*]|[0-9]+[.)])[[:space:]]+)?\*\*In Codex:\*\*/) { label = asked ? "codex" : "early"; label_at = FNR; reset_at = 0 }
      }
      check("codex exec", "claude", "Claude Code")
      check("claude -p", "codex", "Codex")
    }
  ' "$@"
}

# Self-test: the rule must pass a canonical body and flag each way of
# breaking it, so a regression in the rule itself fails CI.
self_test() {
  local t rc=0 out f want
  t="$(mktemp -d)"
  cat >"$t/good.md" <<'EOF'
# Good

## Second opinion

Which CLI am I running in? Take only this CLI's branch; never call your own CLI.

- **In Claude Code:** the other reviewer is Codex:

  ```bash
  # A comment in a fence is not a heading.
  codex exec --cd "$PWD" --sandbox read-only - < "$PROMPT_FILE"
  ```

  Long inline prompts can hang `codex exec`.
- **In Codex:** the other reviewer is Claude: `claude -p --permission-mode plan < "$PROMPT_FILE"`.

1. **In Claude Code:** check `codex exec --help` first.
EOF
  cat >"$t/self-call.md" <<'EOF'
# Self-call

Which CLI am I running in?

- **In Claude Code:** run `claude -p --permission-mode plan < "$PROMPT_FILE"`.
EOF
  cat >"$t/unlabeled.md" <<'EOF'
# Unlabeled

Which CLI am I running in? Ask the other one:

```bash
codex exec --cd "$PWD" --sandbox read-only - < "$PROMPT_FILE"
```
EOF
  cat >"$t/heading-reset.md" <<'EOF'
# Heading reset

Which CLI am I running in?

- **In Codex:** the other reviewer is Claude.

## Next step

claude -p --permission-mode plan < "$PROMPT_FILE"
EOF
  cat >"$t/label-first.md" <<'EOF'
# Label first

- **In Claude Code:** `codex exec --cd "$PWD" --sandbox read-only - < "$PROMPT_FILE"`

Which CLI am I running in?
EOF
  out="$(own_cli_rule "$t/good.md")"
  if [ -n "$out" ]; then echo "SELF-TEST: the own-CLI rule flagged a canonical body:"; printf '%s\n' "$out"; rc=1; fi
  for f in self-call:self-call unlabeled:unlabeled heading-reset:heading label-first:"before any"; do
    want="${f#*:}"; f="${f%%:*}"
    out="$(own_cli_rule "$t/$f.md")"
    if ! grep -q -- "$want" <<<"$out"; then
      echo "SELF-TEST: the own-CLI rule did not flag $f.md ($want); it printed: ${out:-nothing}"; rc=1
    fi
  done
  rm -rf "$t"
  return "$rc"
}
if ! self_test; then fail=1; fi

if [ "$write" -eq 1 ]; then
  wrote=0
  for src in "$SRC"/*/SKILL.md; do
    n="$(basename "$(dirname "$src")")"
    [ "$n" = "$CODEX_ONLY" ] && continue
    dst="$DST/$n/SKILL.md"
    if [ -f "$dst" ] && [ ! -L "$dst" ] && cmp -s "$src" "$dst"; then continue; fi
    if [ -e "$dst" ] || [ -L "$dst" ]; then what=refreshed; else what=created; fi
    mkdir -p "$DST/$n"
    rm -f "$dst"
    cp "$src" "$dst"
    echo "$what $dst from $src"
    wrote=$((wrote + 1))
  done
  [ "$wrote" -gt 0 ] || echo "every Claude copy already matches its source"
fi

# No Claude commands upstream: every workflow is a skill. (git rm leaves an
# empty folder behind; remove it too.)
if [ -e .claude/commands ] || [ -L .claude/commands ]; then
  echo "COMMANDS: .claude/commands/ exists; workflows ship as .claude/skills/<name>/SKILL.md, so remove it"; fail=1
fi

# Sources: each has its manifest, and (except the Codex-only helper) a
# byte-identical Claude copy alone in its folder.
sources=0
copies=0
for d in "$SRC"/*/; do
  n="$(basename "$d")"
  sources=$((sources + 1))
  src="$SRC/$n/SKILL.md"
  yaml="$SRC/$n/agents/openai.yaml"
  if [ ! -f "$src" ]; then
    echo "MISSING SOURCE: $SRC/$n/ has no SKILL.md"; fail=1
  fi
  if [ ! -f "$yaml" ]; then
    echo "MISSING MANIFEST: $SRC/$n/ has no agents/openai.yaml"; fail=1
  elif ! grep -qE "default_prompt:.*\\\$$n([^A-Za-z0-9_-]|\$)" "$yaml"; then
    echo "MANIFEST DRIFT: $yaml default_prompt does not name \$$n"; fail=1
  fi
  if [ "$n" = "$CODEX_ONLY" ]; then
    if [ -e "$DST/$n" ]; then
      echo "ASK PAIR: $DST/$n/ must not exist; $n is Codex-only (Claude uses $CLAUDE_ONLY)"; fail=1
    fi
    continue
  fi
  [ -f "$src" ] || continue
  dst="$DST/$n/SKILL.md"
  if [ -L "$dst" ]; then
    echo "COPY DRIFT: $dst is a symlink; it must be a plain copy (run: bash tests/check-single-source.sh --write)"; fail=1
  elif [ ! -f "$dst" ]; then
    echo "MISSING COPY: $src has no Claude copy $dst (run: bash tests/check-single-source.sh --write)"; fail=1
  elif ! cmp -s "$src" "$dst"; then
    echo "COPY DRIFT: $dst differs from $src (edit the source, then run: bash tests/check-single-source.sh --write)"; fail=1
  else
    copies=$((copies + 1))
  fi
  if [ -d "$DST/$n" ]; then
    extra=""
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      if git check-ignore -q -- "$f" 2>/dev/null; then continue; fi
      extra="$extra ${f#"$DST/$n/"}"
    done <<<"$(find "$DST/$n" -mindepth 1 ! -path "$dst" ! -type d)"
    if [ -n "$extra" ]; then
      echo "EXTRA FILES: $DST/$n/ holds more than SKILL.md:$extra (resources live in $SRC/$n/)"; fail=1
    fi
  fi
done

# Claude skills: each (except the Claude-only helper) is a copy of a source.
for d in "$DST"/*/; do
  [ -d "$d" ] || continue
  n="$(basename "$d")"
  if [ "$n" = "$CLAUDE_ONLY" ]; then
    [ -f "$DST/$n/SKILL.md" ] || { echo "ASK PAIR: $DST/$n/ has no SKILL.md"; fail=1; }
    if [ -e "$SRC/$n" ]; then
      echo "ASK PAIR: $SRC/$n/ must not exist; $n is Claude-only (Codex uses $CODEX_ONLY)"; fail=1
    fi
    continue
  fi
  if [ ! -f "$SRC/$n/SKILL.md" ]; then
    echo "ORPHAN COPY: $DST/$n/ has no source $SRC/$n/SKILL.md"; fail=1
  fi
done
for f in "$DST"/*; do
  [ -e "$f" ] || [ -L "$f" ] || continue
  [ -d "$f" ] && [ ! -L "$f" ] && continue
  echo "STRAY: $f is not a skill folder"; fail=1
done

# The ask pair: each side exists, calls the other CLI, and never its own.
ask_claude="$DST/$CLAUDE_ONLY/SKILL.md"
ask_codex="$SRC/$CODEX_ONLY/SKILL.md"
for f in "$ask_claude" "$ask_codex"; do
  [ -f "$f" ] || { echo "ASK PAIR: $f is missing"; fail=1; }
done
if [ -f "$ask_claude" ]; then
  grep -q 'codex exec' "$ask_claude" || { echo "XAGENT DRIFT: $ask_claude never calls codex exec"; fail=1; }
  if grep -n 'claude -p' "$ask_claude"; then
    echo "XAGENT DRIFT: $ask_claude (Claude-only) mentions claude -p, its own CLI (lines above)"; fail=1
  fi
fi
if [ -f "$ask_codex" ]; then
  grep -q 'claude -p' "$ask_codex" || { echo "XAGENT DRIFT: $ask_codex never calls claude -p"; fail=1; }
  if grep -n 'codex exec' "$ask_codex"; then
    echo "XAGENT DRIFT: $ask_codex (Codex-only) mentions codex exec, its own CLI (lines above)"; fail=1
  fi
fi

# Shared bodies: cross-agent calls go both ways, and only inside the labeled
# branch for the CLI that is running.
xagent=0
shared=()
for src in "$SRC"/*/SKILL.md; do
  n="$(basename "$(dirname "$src")")"
  [ "$n" = "$CODEX_ONLY" ] && continue
  has_codex="$(grep -c 'codex exec' "$src" || true)"
  has_claude="$(grep -c 'claude -p' "$src" || true)"
  if [ "$has_codex" -gt 0 ] && [ "$has_claude" -eq 0 ]; then
    echo "XAGENT DRIFT: $src calls codex exec from Claude Code but never claude -p from Codex"; fail=1
  elif [ "$has_claude" -gt 0 ] && [ "$has_codex" -eq 0 ]; then
    echo "XAGENT DRIFT: $src calls claude -p from Codex but never codex exec from Claude Code"; fail=1
  elif [ "$has_codex" -gt 0 ]; then
    xagent=$((xagent + 1))
  fi
  while IFS= read -r f; do
    if [ -n "$f" ]; then shared+=("$f"); fi
  done <<<"$(find "$SRC/$n" -name '*.md' -type f | LC_ALL=C sort)"
done
if [ "${#shared[@]}" -gt 0 ]; then
  own="$(own_cli_rule "${shared[@]}")"
  if [ -n "$own" ]; then
    printf '%s\n' "$own"
    echo "OWN-CLI DRIFT: shared bodies must call codex exec only under **In Claude Code:** and claude -p only under **In Codex:**, after a \"Which CLI am I running in\" line (findings above)"; fail=1
  fi
fi

# Read-only + stdin invariants: any flagged secondary-CLI invocation must be
# read-only AND take its prompt via stdin from a file — never inline (long
# inline prompts hang codex exec). Bare prose mentions (no flags) are ignored;
# `codex exec --help` (preflight) is exempt. Claude copies are byte-identical
# to their sources, so only the sources and the Claude-only helper are read.
scan=()
for p in "$SRC" "$DST/$CLAUDE_ONLY" AGENTS.md docs/cross-agent-review.md; do
  if [ -e "$p" ]; then scan+=("$p"); fi
done
if grep -rn 'codex exec --' "${scan[@]}" \
   | grep -v 'codex exec --help' | grep -v -- '--sandbox read-only -'; then
  echo "INVOCATION DRIFT: codex exec must use '--sandbox read-only -' with a file-piped prompt (lines above)"; fail=1
fi
if grep -rn 'claude -p' "${scan[@]}" \
   | grep -vE -- '--permission-mode plan *<'; then
  echo "INVOCATION DRIFT: claude -p must use '--permission-mode plan < file' (lines above)"; fail=1
fi

# Belt-and-braces: the historical inline '"<prompt>"' form must never return.
if grep -rnE '(codex exec|claude -p).*"<' "${scan[@]}"; then
  echo "INLINE PROMPT: cross-agent invocation passes the prompt inline (lines above) — use the temp-file stdin form"; fail=1
fi

# Anchored-review verdict contract: any file that inlines the anchored output
# contract, plus the breakdown plan-review source, must carry the exact
# verdict line — otherwise the verdict vocabulary silently forks.
VERDICT_LINE='VERDICT: APPROVE | REVISE | RETHINK'
contract="$(grep -rl 'SUGGESTED CHANGES:' "${scan[@]}" || true)"
for f in $contract "$SRC/breakdown/SKILL.md"; do
  if [ ! -f "$f" ]; then
    echo "CONTRACT DRIFT: $f is missing"; fail=1
  elif ! grep -qF "$VERDICT_LINE" "$f"; then
    echo "CONTRACT DRIFT: $f is missing the exact '$VERDICT_LINE' line"; fail=1
  fi
done

if [ "$fail" -eq 0 ]; then
  echo "single-source OK: $sources sources, $copies byte-identical Claude copies (ask-codex/ask-claude kept apart), manifests present, $xagent cross-agent bodies labeled per CLI, invocations read-only + file-piped"
fi
exit "$fail"

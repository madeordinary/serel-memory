#!/usr/bin/env bash
# The same preflight runs locally and in GitHub Actions. See CONTRIBUTING.md.
set -euo pipefail
cd "$(dirname "$0")/.."
mode="${1:-all}"
case "$mode" in
  checks|docs|all) ;;
  *) echo "usage: bash tests/ci.sh [checks|docs|all]" >&2; exit 2 ;;
esac
tmp="$(mktemp -d)"
tmp="$(cd "$tmp" && pwd -P)"
trap 'rm -rf "$tmp"' EXIT

checks() {
  command -v jq >/dev/null || { echo "Install jq before running the checks." >&2; exit 1; }
  if [ "$(git rev-parse --is-shallow-repository)" = true ]; then
    echo "Checks need full history: run git fetch --unshallow --tags." >&2
    exit 1
  fi
  for tag in v0.1.0 v0.2.0 v0.3.0; do
    git rev-parse --verify "refs/tags/$tag^{commit}" >/dev/null || {
      echo "Missing fixture tag $tag: run git fetch origin --tags." >&2
      exit 1
    }
  done
  shellcheck_bin="$(bash .github/ci/shellcheck.sh "$tmp")"
  printf 'ShellCheck: %s\n' "$shellcheck_bin"
  "$shellcheck_bin" --version
  "$shellcheck_bin" hooks/*.sh hooks/lib/*.sh tests/*.sh bin/serel-memory .github/ci/*.sh
  for suite in tests/check-*.sh tests/smoke-*.sh; do
    printf '\n==> %s\n' "$suite"
    bash "$suite"
  done
}

docs() {
  expected_node="v$(cat .github/ci/node-version)"
  if ! command -v node >/dev/null || [ "$(node --version)" != "$expected_node" ]; then
    echo "Use Node $expected_node (see .github/ci/node-version), then retry." >&2
    exit 1
  fi
  mkdir "$tmp/markdownlint"
  cp .github/ci/package.json .github/ci/package-lock.json "$tmp/markdownlint/"
  npm ci --prefix "$tmp/markdownlint" --include=dev --ignore-scripts --no-audit --no-fund
  node "$tmp/markdownlint/node_modules/markdownlint-cli2/markdownlint-cli2-bin.mjs" '**/*.md'
}

case "$mode" in
  checks) checks ;;
  docs) docs ;;
  all) checks; docs ;;
esac

#!/usr/bin/env bash
# Serel Memory local installer.
#
# Usage: install.sh <target-repo> --local [--apply]
#
# Copies the Serel Memory framework and the starter bank from this checkout
# into the root of a git repository and keeps every copied path out of Git in
# that clone, through the repository's own info/exclude. Without --apply it
# prints the plan and writes nothing to the target. With --apply it writes the
# exclusions first, verifies them, and only then copies files.
#
# It never edits, stages, or untracks a tracked file, never overwrites an
# existing file, and never registers hooks. Shared (committed) installs use the
# README's install commands instead. Guide: docs/serel-setup.md "Local install".
#
# Requires: bash and git. Runs from a git checkout of Serel Memory, because the
# checkout is what records which version gets installed.
set -euo pipefail

# Read-only git calls must not refresh an index, and nothing inherited from a
# calling git process may redirect which repository these commands touch.
export GIT_OPTIONAL_LOCKS=0
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR

UPSTREAM="madeordinary/serel-memory"
# The sync-upstream framework allowlist (.claude/commands/sync-upstream.md).
# tests/check-allowlist.sh keeps this copy equal to it.
FRAMEWORK_PATHS=(.agents/skills/ .claude/commands/ AGENTS.md \
  docs/workflow-contract.md docs/cross-agent-review.md docs/serel-setup.md hooks/ bin/serel-memory)
BANK_FILES=(projectbrief productContext systemPatterns techContext decisionLog activeContext progress)
EXCLUDE_HEADER="# Serel Memory local install (install.sh --local): kept out of Git in this clone"

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'USAGE_END'
Usage: install.sh <target-repo> --local [--apply]

Installs Serel Memory into a git repository for this clone only: the files are
copied and excluded from Git through the repository's info/exclude.

Options:
  --local    required; the only mode this script provides
  --apply    write the previewed plan (without it, nothing is written)
  -h, --help show this text

Rules:
  - The target must be the root of a git work tree (a linked worktree is fine).
  - A tracked destination (names compared without case), an existing name
    that differs only in case, or an existing file that differs, stops the
    run before anything is written. An existing AGENTS.md is left alone.
  - Re-running changes nothing and keeps the bank, .rules, and the anchor.
  - For a shared install that you commit, see the README's Install section.
USAGE_END
}

# --- arguments ---------------------------------------------------------------

target=""
local_mode=0
apply=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --local) local_mode=1; shift ;;
    --apply) apply=1; shift ;;
    -*) die "unknown option: $1" ;;
    *)
      [ -z "$target" ] || die "only one target is allowed (got '$target' and '$1')"
      target="$1"; shift ;;
  esac
done
if [ -z "$target" ]; then usage >&2; exit 1; fi
[ "$local_mode" -eq 1 ] ||
  die "this script only installs with --local; for a shared (committed) install see the README's Install section"
command -v git >/dev/null 2>&1 || die "git is required"

# --- source: this checkout ---------------------------------------------------

SRC="$(cd "$(dirname "$0")" && pwd -P)"
src_top="$(git -C "$SRC" rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$src_top" ] || [ "$(cd "$src_top" && pwd -P)" != "$SRC" ]; then
  die "run install.sh from the root of a git checkout of Serel Memory (git clone), not from a copy; the checkout records which version is installed"
fi

# --- target ------------------------------------------------------------------

[ -d "$target" ] || die "target is not a directory: $target"
target="$(cd "$target" && pwd -P)"
top="$(git -C "$target" rev-parse --show-toplevel 2>/dev/null || true)"
[ -n "$top" ] || die "target is not a git work tree: $target"
top="$(cd "$top" && pwd -P)"
[ "$top" = "$target" ] || die "target must be the repository root, which is: $top"
case "$target/" in
  "$SRC"/*) die "target is the source checkout or inside it: $target" ;;
esac
case "$SRC/" in
  "$target"/*) die "the source checkout is inside the target; clone Serel Memory somewhere else, such as a temporary folder" ;;
esac

# --- payload -----------------------------------------------------------------

# Only a declared path is ever written: [A-Za-z0-9_./-] only (so it is also a
# literal info/exclude pattern), no empty, `.` or `..` segment.
valid_rel() {
  [[ "$1" =~ ^[A-Za-z0-9_./-]+$ ]] || return 1
  case "/$1/" in *"/../"*|*"/./"*|*"//"*) return 1 ;; esac
  return 0
}

bank_paths=()
for b in "${BANK_FILES[@]}"; do bank_paths+=("memory-bank/$b.md"); done
payload_spec=("${FRAMEWORK_PATHS[@]}" "${bank_paths[@]}" .rules)

# Tracked plus new, non-ignored files: a new framework file installs before it
# is committed, while ignored clutter (editor files, local settings) never does.
listed="$(git -C "$SRC" ls-files -co --exclude-standard -- "${payload_spec[@]}")" ||
  die "could not list the payload in $SRC"
payload=()
while IFS= read -r rel; do
  [ -n "$rel" ] || continue
  valid_rel "$rel" || die "unexpected payload path in the source: $rel"
  if [ -L "$SRC/$rel" ] || [ ! -f "$SRC/$rel" ]; then
    die "payload file is missing or not a regular file in the source: $rel"
  fi
  payload+=("$rel")
done < <(printf '%s\n' "$listed" | LC_ALL=C sort -u)
[ "${#payload[@]}" -gt 0 ] || die "no payload found in $SRC"

in_payload() {
  local p
  for p in "${payload[@]}"; do [ "$p" = "$1" ] && return 0; done
  return 1
}
for rel in AGENTS.md .rules bin/serel-memory docs/serel-setup.md .claude/commands/start.md \
  .agents/skills/start/SKILL.md "${bank_paths[@]}"; do
  in_payload "$rel" || die "the source checkout is incomplete: $rel is missing"
done

# --- provenance --------------------------------------------------------------

head_sha="$(git -C "$SRC" rev-parse --verify -q 'HEAD^{commit}')" || die "the source checkout has no commit"
dirty="$(git -C "$SRC" status --porcelain --untracked-files=all -- "${payload_spec[@]}")" ||
  die "could not read the source checkout's status"
tag="$(git -C "$SRC" describe --tags --exact-match --match 'v[0-9]*' HEAD 2>/dev/null || true)"
# Only a release-shaped tag (vMAJOR.MINOR.PATCH, optionally -prerelease) names
# the version. Any other tag name falls back to the SHA, so the anchor stays
# valid JSON whatever characters a tag holds.
release_re='^v[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$'
[[ "$tag" =~ $release_re ]] || tag=""
if [ -n "$dirty" ]; then
  # Uncommitted bytes are no version at all: name the commit they sit on and
  # mark the anchor linked, which sync-upstream reads as "exact start unknown".
  ref="$head_sha"; linked=true
  source_label="commit $head_sha plus uncommitted changes (not a release)"
elif [ -n "$tag" ]; then
  ref="$tag"; linked=false
  source_label="$tag (clean checkout of that tag)"
else
  ref="$head_sha"; linked=false
  source_label="commit $head_sha (clean, not a release tag)"
fi
anchor_json="{ \"upstream\": \"$UPSTREAM\", \"ref\": \"$ref\", \"linked\": $linked }"

work="$(mktemp -d)"
printf '%s\n' "$anchor_json" >"$work/anchor"
source_of() {
  if [ "$1" = .serel-memory.json ]; then printf '%s\n' "$work/anchor"; else printf '%s\n' "$SRC/$1"; fi
}

# --- rollback ----------------------------------------------------------------

applying=0
success=0
written=()
created_dirs=()
exclude_changed=0
exclude_existed=0
created_info=0
keep_work=0

# Undo ordinary failures of this run, exclusions included. Not crash-atomic:
# run one install at a time.
cleanup() {
  local rc=$? n
  trap - EXIT
  set +e
  if [ "$applying" -eq 1 ] && [ "$success" -eq 0 ]; then
    printf 'Apply failed; undoing this run.\n' >&2
    for ((n = ${#written[@]} - 1; n >= 0; n--)); do
      rm -f -- "$target/${written[$n]}"
    done
    for ((n = ${#created_dirs[@]} - 1; n >= 0; n--)); do
      rmdir -- "$target/${created_dirs[$n]}" 2>/dev/null
    done
    if [ "$exclude_changed" -eq 1 ]; then
      if [ "$exclude_existed" -eq 1 ]; then
        if ! cat "$work/exclude.orig" >"$exclude"; then
          printf 'RESTORE FAILED: %s (original kept at %s)\n' "$exclude" "$work/exclude.orig" >&2
          keep_work=1
        fi
      else
        rm -f -- "$exclude"
        [ "$created_info" -eq 0 ] || rmdir -- "$info_dir" 2>/dev/null
      fi
    fi
    [ "$rc" -ne 0 ] || rc=1
  fi
  [ "$keep_work" -eq 1 ] || rm -rf "$work"
  exit "$rc"
}
trap cleanup EXIT

# --- the target's exclude file -----------------------------------------------

# Git resolves info/exclude: in a linked worktree it lives in the common git
# directory, so it applies to every worktree while the files stay in this one.
exclude="$(git -C "$target" rev-parse --git-path info/exclude)" || die "could not locate info/exclude"
case "$exclude" in /*) ;; *) exclude="$target/$exclude" ;; esac
info_dir="$(dirname "$exclude")"

problems=()
problem() { problems+=("$*"); }

if [ -L "$info_dir" ] || { [ -e "$info_dir" ] && [ ! -d "$info_dir" ]; }; then
  problem "$info_dir is not a plain directory"
elif [ -L "$exclude" ] || { [ -e "$exclude" ] && [ ! -f "$exclude" ]; }; then
  problem "$exclude is a symlink or not a regular file"
elif [ -e "$exclude" ] && [ -n "$(find "$exclude" -prune -links +1 -print)" ]; then
  problem "$exclude has multiple hard links"
fi
exclude_text=""
if [ -f "$exclude" ] && [ ! -L "$exclude" ]; then exclude_text="$(cat "$exclude")"; fi
in_exclude() {
  case $'\n'"$exclude_text"$'\n' in *$'\n'"$1"$'\n'*) return 0 ;; esac
  return 1
}

# --- plan --------------------------------------------------------------------

# Listed without case (`:(icase)`): on a case-insensitive filesystem a tracked
# `.RULES` is the same file as `.rules`, and refusing such a name is the safe
# answer on a case-sensitive one too. -z keeps unusual names unquoted.
icase_specs=()
for n in .agents .claude AGENTS.md docs hooks bin memory-bank .rules .serel-memory.json; do
  icase_specs+=(":(icase)$n")
done
tracked="$(git -C "$target" ls-files -z -- "${icase_specs[@]}" | tr '\0' '\n')" ||
  die "could not list tracked files in the target"
is_tracked() {
  case $'\n'"$tracked"$'\n' in *$'\n'"$1"$'\n'*) return 0 ;; esac
  return 1
}
# Prints the first tracked path that is <path> or lies inside it, compared
# without case (ASCII). With a second argument, paths inside <path> spelled
# exactly are skipped: a team's own files beside the installed ones are fine.
tracked_match() {
  LC_ALL=C awk -v p="$1" -v skip_exact="${2:-}" '
    BEGIN { q = tolower(p) }
    { l = tolower($0) }
    (l == q || index(l, q "/") == 1) && !(skip_exact != "" && index($0, p "/") == 1) { print; exit }
  ' <<<"$tracked"
}

# Prints the name the filesystem stores for an existing <acc>. On a
# case-insensitive filesystem `[ -e .claude ]` also answers for `.Claude`,
# which Git's exclude lines may not match.
stored_name() {
  local dir="$target" base="${1##*/}" hit
  case "$1" in */*) dir="$target/${1%/*}" ;; esac
  hit="$(find "$dir" -mindepth 1 -maxdepth 1 -name "$base" -print)"
  [ -n "$hit" ] || hit="$(find "$dir" -mindepth 1 -maxdepth 1 -iname "$base" -print)"
  hit="${hit%%$'\n'*}"
  printf '%s\n' "${hit##*/}"
}

# Sets `why` to the reason writing <rel> would be unsafe: a symlink, a
# non-directory, a tracked file or submodule, or a nested repository on the
# way; an existing name stored with other capitalization; a tracked path that
# matches only when case is ignored; or an existing destination that is not a
# plain single-link file. Directories already cleared are not checked again.
cleared=$'\n'
path_problem() {
  local rest="$1" acc="" seg abs hit stored
  why=""
  while [ -n "$rest" ]; do
    seg="${rest%%/*}"
    if [ "$seg" = "$rest" ]; then rest=""; else rest="${rest#*/}"; fi
    acc="${acc:+$acc/}$seg"
    abs="$target/$acc"
    case "$cleared" in *$'\n'"$acc"$'\n'*) continue ;; esac
    if [ -L "$abs" ]; then why="$acc is a symlink"; return; fi
    hit="$(tracked_match "$acc" skip-exact)"
    if [ -n "$hit" ] && [ "$hit" = "$acc" ] && [ -n "$rest" ]; then
      why="$acc is tracked as a file or submodule"; return
    elif [ -n "$hit" ] && [ "$hit" != "$acc" ]; then
      why="$acc matches the tracked path $hit when case is ignored"; return
    fi
    if [ -e "$abs" ]; then
      stored="$(stored_name "$acc")"
      if [ "$stored" != "$seg" ]; then
        why="$acc already exists as ${stored:-another name}, which differs only in case"
        return
      fi
    fi
    if [ -n "$rest" ]; then
      if [ -e "$abs" ]; then
        if [ ! -d "$abs" ]; then why="$acc is not a directory"; return; fi
        if [ -e "$abs/.git" ]; then why="$acc is a separate git repository"; return; fi
      fi
      cleared="$cleared$acc"$'\n'
    elif [ -e "$abs" ]; then
      if [ ! -f "$abs" ]; then why="$acc is not a regular file"; return; fi
      if [ -n "$(find "$abs" -prune -links +1 -print)" ]; then why="$acc has multiple hard links"; return; fi
    fi
  done
}

hit="$(tracked_match .serel-memory.json)"
[ -n "$hit" ] || hit="$(tracked_match memory-bank)"
if [ -n "$hit" ]; then
  problem "this repository already tracks .serel-memory.json or files under memory-bank/ ($hit, compared without case); resume with /start or \$start, and update a shared install with sync-upstream"
fi

copy=()
keep=()
skipped_agents=0
lines=()
add_line() {
  local l
  for l in ${lines[@]+"${lines[@]}"}; do [ "$l" = "$1" ] && return 0; done
  lines+=("$1")
}

for rel in "${payload[@]}" .serel-memory.json; do
  if [ "$rel" = AGENTS.md ]; then
    # Existing instructions belong to the project: never replaced, never hidden.
    # The exception is a local AGENTS.md that an earlier run installed and
    # excluded; it is kept as it is, edits included. Names are compared without
    # case, so an `agents.md` also counts as existing instructions.
    agents_hit="$(tracked_match AGENTS.md)"
    if [ -e "$target/AGENTS.md" ] || [ -L "$target/AGENTS.md" ] || [ -n "$agents_hit" ]; then
      if in_exclude /AGENTS.md && [ -z "$agents_hit" ] && [ -f "$target/AGENTS.md" ] && [ ! -L "$target/AGENTS.md" ] &&
        [ "$(stored_name AGENTS.md)" = AGENTS.md ]; then
        keep+=(AGENTS.md)
        add_line /AGENTS.md
      else
        skipped_agents=1
      fi
      continue
    fi
  fi
  case "$rel" in
    memory-bank/*) line="/memory-bank/"; kind=memory ;;
    .rules|.serel-memory.json) line="/$rel"; kind=memory ;;
    *) line="/$rel"; kind=framework ;;
  esac
  path_problem "$rel"
  if [ -n "$why" ]; then problem "UNSAFE PATH: $why"; continue; fi
  if is_tracked "$rel"; then problem "tracked by this repository: $rel"; continue; fi
  if [ ! -e "$target/$rel" ]; then
    copy+=("$rel")
  elif cmp -s "$(source_of "$rel")" "$target/$rel"; then
    keep+=("$rel")
  elif [ "$kind" = memory ] && in_exclude "$line"; then
    keep+=("$rel")   # this clone's memory: an earlier local install excluded it
  else
    problem "exists and differs from this checkout: $rel (the installer never overwrites)"
    continue
  fi
  add_line "$line"
done

# /memory-bank/ is excluded as a whole, so later archives and optional docs stay
# local too. On a first install that must not hide anything already there.
if ! in_exclude "/memory-bank/" && [ -d "$target/memory-bank" ] && [ ! -L "$target/memory-bank" ]; then
  while IFS= read -r entry; do
    [ -n "$entry" ] || continue
    rel="${entry#"$target"/}"
    case " ${keep[*]-} " in *" $rel "*) continue ;; esac
    problem "memory-bank/ already holds $rel; excluding memory-bank/ would hide it"
  done < <(find "$target/memory-bank" -mindepth 1 \( -type d -empty -o ! -type d \) -print | LC_ALL=C sort)
fi

missing=()
for l in ${lines[@]+"${lines[@]}"}; do in_exclude "$l" || missing+=("$l"); done
installed=(${copy[@]+"${copy[@]}"} ${keep[@]+"${keep[@]}"})

# memory-bank/ must be ignored as a folder, not only file by file, or a later
# archive or optional doc under it shows up in Git. `memory-bank/` asks Git
# about the folder as the parent of anything below it, even before it exists;
# once it exists, `memory-bank` asks about the folder itself, exactly. Probes
# are checked, never copied.
bank_probes() {
  probes=(memory-bank/)
  if [ -d "$target/memory-bank" ] && [ ! -L "$target/memory-bank" ]; then probes+=(memory-bank); fi
}

# Prove every installed path, and the bank folder, will be ignored before
# writing anything. A stand-in excludes file holds the planned patterns; it
# ranks below the real info/exclude and every .gitignore, so any rule that
# would re-include a path (a `!` negation) still wins here and is reported.
if [ "${#problems[@]}" -eq 0 ] && [ "${#installed[@]}" -gt 0 ]; then
  printf '%s\n' "${lines[@]}" >"$work/planned-exclude"
  bank_probes
  checked=("${installed[@]}" "${probes[@]}")
  rc=0
  ignored="$(git -C "$target" -c core.excludesFile="$work/planned-exclude" check-ignore --no-index -- "${checked[@]}")" || rc=$?
  [ "$rc" -le 1 ] || die "git check-ignore failed (status $rc)"
  defeated=()
  for rel in "${checked[@]}"; do
    case $'\n'"$ignored"$'\n' in *$'\n'"$rel"$'\n'*) ;; *) defeated+=("$rel") ;; esac
  done
  if [ "${#defeated[@]}" -gt 0 ]; then
    rules="$(git -C "$target" -c core.excludesFile="$work/planned-exclude" check-ignore --no-index -v -n -- "${defeated[@]}" || true)"
    bank_defeated=0
    bank_rule=""
    while IFS= read -r r; do
      case "$r" in
        '') ;;
        *$'\t'memory-bank|*$'\t'memory-bank/)
          bank_defeated=1
          [ "${r%%$'\t'*}" = "::" ] || bank_rule="${r%%$'\t'*}" ;;
        *) problem "an existing ignore rule keeps this path visible to Git: $r" ;;
      esac
    done < <(printf '%s\n' "$rules")
    if [ "$bank_defeated" -eq 1 ]; then
      problem "an existing ignore rule keeps the memory-bank/ folder visible to Git, so files added under it later would show: ${bank_rule:-a negation such as !/memory-bank/}"
    fi
  fi
fi

# --- report ------------------------------------------------------------------

if [ "${#problems[@]}" -gt 0 ]; then
  printf 'Serel Memory local install: refused for %s\n' "$target" >&2
  for p in "${problems[@]}"; do printf '  - %s\n' "$p" >&2; done
  printf 'Nothing was written.\n' >&2
  exit 1
fi

if [ "$apply" -eq 1 ]; then
  printf 'Serel Memory local install: applying\n'
else
  printf 'Serel Memory local install: preview (nothing written)\n'
fi
printf 'Source:  %s at %s\n' "$SRC" "$source_label"
printf 'Target:  %s\n' "$target"
printf 'Exclude: %s (Git applies it in every worktree of this repository)\n' "$exclude"
if [ "$linked" = true ]; then
  printf '\nWarning: the source has uncommitted payload changes. The anchor records the\n'
  printf 'commit they sit on with "linked": true, meaning the exact version is unknown.\n'
fi

if [ "${#copy[@]}" -gt 0 ]; then
  printf '\nCopy (%d new files, kept out of Git):\n' "${#copy[@]}"
  printf '  %s\n' "${copy[@]}"
fi
if [ "${#keep[@]}" -gt 0 ]; then
  printf '\nAlready here (left as they are):\n'
  printf '  %s\n' "${keep[@]}"
fi
if [ "$skipped_agents" -eq 1 ]; then
  printf '\nNot installed: AGENTS.md. The repository already has one and it stays as it is.\n'
  printf "Start each session with /start (Claude Code) or \$start (Codex).\n"
fi
if [ "${#missing[@]}" -gt 0 ]; then
  printf '\nExclude lines to add (%d):\n' "${#missing[@]}"
  printf '  %s\n' "${missing[@]}"
fi
case " ${copy[*]-} " in
  *" .serel-memory.json "*) printf '\nAnchor (.serel-memory.json): %s\n' "$anchor_json" ;;
esac

cat <<'LIMITS_END'

These files stay in this clone only. Nothing tracked, staged, or committed
changes. Git does not back them up: `git clean -x` or `-X` deletes them, and
`git add -f` can still commit them. This keeps files out of commits; it is not
a security boundary.
LIMITS_END

if [ "${#copy[@]}" -eq 0 ] && [ "${#missing[@]}" -eq 0 ]; then
  printf '\nNothing to do: Serel Memory is already installed locally here.\n'
  exit 0
fi
if [ "$apply" -eq 0 ]; then
  printf '\nRun again with --apply to install.\n'
  exit 0
fi

# --- apply -------------------------------------------------------------------

# Every listed path, and the bank folder, must be ignored by the real
# repository, and none tracked. After the copy the folder exists, so the
# folder itself is checked exactly.
verify_hidden() {
  local rc=0 out rel
  bank_probes
  out="$(git -C "$target" check-ignore --no-index -- "${installed[@]}" "${probes[@]}")" || rc=$?
  [ "$rc" -le 1 ] || die "git check-ignore failed (status $rc)"
  for rel in "${installed[@]}" "${probes[@]}"; do
    case $'\n'"$out"$'\n' in *$'\n'"$rel"$'\n'*) ;; *) die "$rel is not ignored after writing the exclusions" ;; esac
  done
}

applying=1

# 1. Exclusions first, so no copied file is ever visible to Git.
if [ "${#missing[@]}" -gt 0 ]; then
  if [ -e "$exclude" ]; then
    cp -p "$exclude" "$work/exclude.orig"
    exclude_existed=1
  elif [ ! -d "$info_dir" ]; then
    mkdir "$info_dir"
    created_info=1
  fi
  exclude_changed=1
  lead=""
  if [ -n "$exclude_text" ] && [ -n "$(tail -c 1 "$exclude")" ]; then lead=$'\n'; fi
  {
    printf '%s' "$lead"
    printf '%s\n' "$EXCLUDE_HEADER"
    printf '%s\n' "${missing[@]}"
  } >>"$exclude"
fi
verify_hidden

# 2. Files. Each destination is re-checked just before it is written.
for rel in ${copy[@]+"${copy[@]}"}; do
  dir="$(dirname "$rel")"
  if [ "$dir" != . ]; then
    acc=""
    rest="$dir"
    while [ -n "$rest" ]; do
      seg="${rest%%/*}"
      if [ "$seg" = "$rest" ]; then rest=""; else rest="${rest#*/}"; fi
      acc="${acc:+$acc/}$seg"
      if [ ! -d "$target/$acc" ]; then
        mkdir -- "$target/$acc"
        created_dirs+=("$acc")
      fi
    done
  fi
  if [ -e "$target/$rel" ] || [ -L "$target/$rel" ]; then die "$rel appeared while installing"; fi
  written+=("$rel")
  cp "$(source_of "$rel")" "$target/$rel"
done

# 3. Postcheck on the real repository: nothing installed is tracked or visible,
# under any capitalization Git may use for it.
verify_hidden
icase_installed=()
for rel in "${installed[@]}"; do icase_installed+=(":(icase)$rel"); done
visible="$(git -C "$target" ls-files --others --exclude-standard -- "${icase_installed[@]}" ':(icase)memory-bank')" ||
  die "could not read the target's untracked files"
[ -z "$visible" ] || die "still visible to Git after installing: $visible"
now_tracked="$(git -C "$target" ls-files -- "${icase_installed[@]}")" || die "could not read the target's index"
[ -z "$now_tracked" ] || die "installed paths are tracked: $now_tracked"

success=1
printf '\nInstalled %d files; %d exclude lines added.\n' "${#copy[@]}" "${#missing[@]}"
printf "Next: open this repository in Claude Code or Codex and run /start or \$start.\n"
printf 'A blank bank leads into seeding; see docs/serel-setup.md.\n'

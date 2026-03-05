#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: preview_merge_changes.sh <target-ref> <source-ref> [--patch]

Shows the real net changes introduced by merging <source-ref> into <target-ref>,
including a commit comparison that filters cherry-pick-equivalent commits.
EOF
}

if [[ $# -lt 2 || $# -gt 3 ]]; then
  usage >&2
  exit 1
fi

target_ref="$1"
source_ref="$2"
show_patch="${3:-}"

if [[ -n "$show_patch" && "$show_patch" != "--patch" ]]; then
  usage >&2
  exit 1
fi

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "Error: must run inside a git repository." >&2
  exit 1
fi

if ! git rev-parse --verify "${target_ref}^{commit}" >/dev/null 2>&1; then
  echo "Error: target ref not found: ${target_ref}" >&2
  exit 1
fi

if ! git rev-parse --verify "${source_ref}^{commit}" >/dev/null 2>&1; then
  echo "Error: source ref not found: ${source_ref}" >&2
  exit 1
fi

merge_tree_sha=""
if git merge-tree -h 2>&1 | grep -q -- '--write-tree'; then
  if ! merge_tree_output="$(git merge-tree --write-tree "${target_ref}" "${source_ref}" 2>&1)"; then
    echo "Error: merge simulation reported conflicts; resolve conflicts to know final exact changes." >&2
    echo "${merge_tree_output}" >&2
    exit 2
  fi

  merge_tree_sha="$(printf '%s\n' "${merge_tree_output}" | awk '/^[0-9a-f]{40}$/ {print; exit}')"
  if [[ -z "${merge_tree_sha}" && "${merge_tree_output}" =~ ^[0-9a-f]{40}$ ]]; then
    merge_tree_sha="${merge_tree_output}"
  fi
fi

if [[ -z "${merge_tree_sha}" ]]; then
  tmp_worktree="$(mktemp -d)"
  cleanup() {
    git worktree remove --force "${tmp_worktree}" >/dev/null 2>&1 || true
    rm -rf "${tmp_worktree}" >/dev/null 2>&1 || true
  }
  trap cleanup EXIT

  git worktree add --quiet --detach "${tmp_worktree}" "${target_ref}" >/dev/null
  if ! merge_output="$(git -C "${tmp_worktree}" merge --no-commit --no-ff --quiet "${source_ref}" 2>&1)"; then
    echo "Error: merge simulation reported conflicts; resolve conflicts to know final exact changes." >&2
    echo "${merge_output}" >&2
    exit 2
  fi

  merge_tree_sha="$(git -C "${tmp_worktree}" write-tree)"
  git -C "${tmp_worktree}" merge --abort >/dev/null 2>&1 || true
  cleanup
  trap - EXIT
fi

echo "== Raw commits (ancestry: ${target_ref}..${source_ref}) =="
git --no-pager log --oneline "${target_ref}..${source_ref}" || true
echo

echo "== Effective commits (cherry-pick equivalents filtered) =="
git --no-pager log --oneline --right-only --cherry-pick "${target_ref}...${source_ref}" || true
echo

echo "== Net file changes from merge result =="
if git diff --quiet "${target_ref}" "${merge_tree_sha}"; then
  echo "(none)"
else
  git --no-pager diff --name-status "${target_ref}" "${merge_tree_sha}"
fi
echo

echo "== Net change summary =="
git --no-pager diff --shortstat "${target_ref}" "${merge_tree_sha}" || true
echo

if [[ "${show_patch}" == "--patch" ]]; then
  echo "== Full patch (target vs simulated merge result) =="
  git --no-pager diff "${target_ref}" "${merge_tree_sha}"
fi

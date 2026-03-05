---
name: merge-change-preview
description: Previews the real net file changes of merging one branch into another, filtering cherry-pick noise. Use when Azure DevOps or git logs show duplicate commits and you need exact merge impact.
---

# Merge Change Preview

Use this skill to answer: "What will actually change in the target branch if we merge this source branch?"

## Why this works

Cherry-picked commits can appear in merge/PR commit lists even when their code is already present in the target branch.
This workflow computes the simulated merge result tree and diffs that tree against target to show real content changes.

## Quick start

```bash
bash .config/shared/skills/merge-change-preview/scripts/preview_merge_changes.sh <target-ref> <source-ref>
```

```powershell
powershell -ExecutionPolicy Bypass -File .config/shared/skills/merge-change-preview/scripts/preview_merge_changes.ps1 <target-ref> <source-ref>
```

Example:

```bash
bash .config/shared/skills/merge-change-preview/scripts/preview_merge_changes.sh origin/main origin/feature/my-branch
```

```powershell
powershell -ExecutionPolicy Bypass -File .config/shared/skills/merge-change-preview/scripts/preview_merge_changes.ps1 origin/main origin/feature/my-branch
```

To include the full patch:

```bash
bash .config/shared/skills/merge-change-preview/scripts/preview_merge_changes.sh origin/main origin/feature/my-branch --patch
```

```powershell
powershell -ExecutionPolicy Bypass -File .config/shared/skills/merge-change-preview/scripts/preview_merge_changes.ps1 origin/main origin/feature/my-branch -Patch
```

## What the output means

- `Raw commits`: commits shown by ancestry (`target..source`), usually what UI commit tabs emphasize.
- `Effective commits`: source-only commits after patch-equivalent cherry-picks are filtered.
- `Net file changes`: exact files that will change in target after the merge result is applied.
- `(none)` under `Net file changes`: merge has no effective content change, even if commit lists are noisy.

## Manual commands

```bash
git --no-pager log --oneline <target>..<source>
git --no-pager log --oneline --right-only --cherry-pick <target>...<source>
MERGE_TREE=$(git merge-tree --write-tree <target> <source>)
git --no-pager diff --name-status <target> "$MERGE_TREE"
git --no-pager diff --shortstat <target> "$MERGE_TREE"
```

## Notes

- Use fully qualified refs (`origin/main`, `origin/release/x`, etc.) to match Azure DevOps merge context.
- Run `git fetch --prune` before analysis if branch tips may be stale.
- Both helper scripts (`.sh` and `.ps1`) auto-fall back to a temporary worktree merge when `git merge-tree --write-tree` is unavailable.
- If merge simulation reports conflicts, conflict resolution can alter the final diff.

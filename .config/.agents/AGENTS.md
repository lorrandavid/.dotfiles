# Personality

Report to me in the Google developer documentation style guide (+ASD-STE100 Simplified Technical English). This applies to reports and prose addressed to me. It does not apply to code comments or commit messages.

# Code Quality Standards

- **Scope**: Do only what the task asks. Do not add unrequested refactors, files, or documentation. Mention adjacent problems instead of fixing them.
- **Editing and searching**: Use dedicated patch tools for edits. Use search tools for searches: `fast-grep` when the host provides it, otherwise `rg`. Do not use `sed` or write custom scripts to edit or search. If a patch fails, re-read the file, adjust the patch, and retry.
- **Comments**: Match the comment density of the surrounding code. Comment the *why*, not the *what*.
- **Make illegal states unrepresentable**: Model domain with ADTs/discriminated unions; parse inputs at boundaries into typed structures; if state can't exist, code can't mishandle it
- **Abstractions**: Prefer deep abstractions with small interfaces. Extract abstractions when they hide meaningful complexity; avoid wrappers that merely rename an operation. Parameterize only what varies today. Document the *why*, not just the *what*.
- **Prefer the smallest correct change**: Prefer fewer helpers and moving parts, while preserving clarity and type safety.
- **Errors and missing data**: Never use fallback defaults to mask missing data or errors (`?? "unknown"`, `|| defaultValue`, speculative `try`/`catch`). If a value can be absent, model it explicitly (e.g., `Option<T>`, nullable field). Prefer typed error results (`Result<T, E>`, discriminated unions) over thrown exceptions for expected failures. Handle real errors explicitly, and otherwise fail clearly. A fallback is acceptable only when it is a genuine, documented business default.
- **Never add legacy compatibility layers unless explicitly asked**: e.g. when refactoring, replace the old implementation with the new one. Do not leave the old code intact while adding adapters, wrappers, or shims to keep it working. Deprecation paths are only acceptable when explicitly requested.
- **Lint and type issues**: Fix issues introduced by your changes. Report unrelated existing issues separately.
- **Verification**: Before you report a task as done, run the typecheck, lint, and relevant tests. Report failures as they are, and say which ones existed before your change.

## TypeScript

- When writing TypeScript, never compromise type safety: no `any`, no non-null assertion operator (`!`), and no type assertions (`as Type`). `as const` and `satisfies` are allowed.
- Never add generic object-shape guards (`isRecord`, `isObject`, `isPlainObject`, or inline equivalents). Parse untrusted inputs at boundaries into concrete domain types using the project's validation approach; use typed values directly inside the application.

# Git Safety

- Do not commit or push unless I ask.
- Do not run destructive commands (`git reset --hard`, `git clean`, `git push --force`, `git checkout -- <path>`, `git worktree remove --force`) unless I ask. Look at the target before you delete or overwrite it.
- Never print or commit secrets, `.env` contents, or tokens.

# Shell

- Use the syntax of the shell you run in. PowerShell and Bash have different syntax; do not mix them.

# Worktrees

Use a worktree when a task needs an isolated checkout. The main checkout is the **original repo**. Never modify its dependency directory from a worktree.

## Create

1. Create the worktree outside the original repo, as a sibling directory: `git worktree add ../<repo>-<task> -b <branch>`.
2. If the repo pins a Node version, use that pin. Do not change `.node-version`, `.nvmrc`, `.tool-versions`, or `package.json` engine fields unless the task requires it.
3. Copy untracked config files that the worktree needs (for example `.env`). Do not link them.

## Share dependencies

Link `node_modules` (or the equivalent dependency directory) from the original repo only when `package.json` and the lockfile are identical in both checkouts. If the task changes dependencies, install them in the worktree instead. A shared link would change the original repo's dependencies.

Linux and macOS (Bash):

```sh
ln -s "$ORIGINAL/node_modules" "$WORKTREE/node_modules"
```

Windows (PowerShell). Use a junction. A junction does not need administrator rights; a symbolic link needs administrator rights or Developer Mode.

```powershell
New-Item -ItemType Junction -Path "$Worktree\node_modules" -Target "$Original\node_modules"
```

For a monorepo, link each package's `node_modules` separately. Link the root `node_modules` and every workspace `node_modules` that exists in the original repo.

Use the repository's own package manager for any dependency change (add, remove, update, dedupe, or lockfile change). Find it from the `packageManager` or `devEngines.packageManager` pin and the committed lockfile. If they disagree, stop and report the conflict. Run `install --frozen-lockfile` only when the manifest and lockfile already describe the desired tree, and never in a worktree whose dependency directory is a link.

## Clean up

A recursive delete can follow a link and delete the original repo's dependencies. Remove links first, then the worktree.

1. Check for work you would lose: `git -C <worktree> status --short` and `git -C <worktree> log @{upstream}..` (or compare to the base branch). Report unmerged or uncommitted work to me. Do not discard it.
2. Remove each dependency link without following it:
   - Linux and macOS: `[ -L "$WORKTREE/node_modules" ] && rm "$WORKTREE/node_modules"`. Use `rm` without `-r` and without a trailing slash.
   - Windows: `cmd /c rmdir "$Worktree\node_modules"`. `rmdir` without `/s` removes only the junction. Do not use `Remove-Item -Recurse` on a junction.
3. Confirm that the original repo's `node_modules` is intact (for example, the directory still exists and is not empty).
4. Remove the worktree: `git worktree remove <worktree>`. Do not use `--force` unless I ask.
5. Run `git worktree prune` to remove stale records.
6. Delete the branch with `git branch -d <branch>` only after it is merged, or when I ask. Do not use `-D` unless I ask.

# Testing

- Write tests that verify semantically correct behavior
- Do not weaken correct tests to make them pass. Report unresolved failures and distinguish existing failures from those introduced by the change.
- **Never** test what the type system already guarantees

# Priority Order

When rules conflict, follow this priority:

1. My explicit instruction in the current request
2. Correctness and type safety
3. Clarity and maintainability
4. Simplicity (less code over more code)
5. Shipping speed

# Personality

Do not use jargon and speak coherently. State it more simply and concisely, like one human talking to another.

# Model and Subagent Cost Control

- Work in the current agent session by default. Do not invoke `Agent`, `Task`, a custom agent, an isolated worker, or any other model-backed subagent unless the user explicitly authorizes subagents in the current request.
- A skill or agent instruction that recommends delegation, parallel agents, or context isolation does not count as user authorization. This rule overrides those recommendations.
- Before any authorized subagent call, verify that it will use the exact same model and reasoning tier selected for the parent session. If the host cannot prove that, do not spawn it; perform the work directly in the parent session.
- Never substitute a supposedly faster, smarter, default, or implementation-specific model variant. In particular, do not allow a `luna` session to delegate to `sol` or another capacity tier.
- Parallelize ordinary non-model tool calls when useful, but keep model reasoning in this session unless the user knowingly opts into the additional model usage.

# Code Quality Standards

- **Editing and searching**: Use dedicated patch tools for edits and search tools such as `rg` for searches. Do not use `sed` or write custom scripts to perform either. If a patch fails, re-read the file, adjust the patch, and retry.
- **Prefer `fast-grep` over `Grep`**: When `fast-grep` is available in the current host, use it instead of `Grep` for codebase searches.
- **Make illegal states unrepresentable**: Model domain with ADTs/discriminated unions; parse inputs at boundaries into typed structures; if state can't exist, code can't mishandle it
- **Abstractions**: Prefer deep abstractions with small interfaces. Extract abstractions when they hide meaningful complexity; avoid wrappers that merely rename an operation. Parameterize only what varies today. Document the *why*, not just the *what*.
- **Prefer the smallest correct change**: Prefer fewer helpers and moving parts, while preserving clarity and type safety.
- **Never use fallback defaults to mask missing data**: No `?? "unknown"`, no `|| defaultValue` to paper over `undefined` that indicates a bug. If a value can be absent, model it explicitly (e.g., `Option<T>`, nullable field). Fallback values are acceptable only when the fallback is a genuine, documented business default — not a way to silence the type checker.
- **Never add legacy compatibility layers unless explicitly asked**: e.g. when refactoring, replace the old implementation with the new one. Do not leave the old code intact while adding adapters, wrappers, or shims to keep it working. Deprecation paths are only acceptable when explicitly requested.
- **Error handling**: Prefer typed error results (`Result<T, E>`, discriminated unions) over thrown exceptions for expected failure modes. Do not add speculative `try`/`catch` blocks with fallback behavior. Handle real errors explicitly, and otherwise fail clearly rather than masking problems with fallbacks unless explicitly asked.
- **Lint and type issues**: Fix issues introduced by your changes. Report unrelated existing issues separately.

## TypeScript

- When writing TypeScript, never compromise type safety: no `any`, no non-null assertion operator (`!`), and no type assertions (`as Type`).
- Never add `isRecord` or equivalent generic object-shape guards such as `isObject` or `isPlainObject`, including renamed or inline equivalents. Parse untrusted inputs at boundaries into concrete domain types using the project's validation approach; use typed values directly inside the application.

# Node.js Tooling

- When `nub` is available on `PATH`, prefer it for Node.js version provisioning and for restoring an existing dependency tree, especially in Git worktrees where its machine-wide cache can be reused.
- Respect the repository's existing Node version pin. Use `nub node install` without a version to provision that pin; do not create or change `.node-version`, `.nvmrc`, `.tool-versions`, or `package.json` engine fields unless the task requires it.
- Use `nub install --frozen-lockfile` only when `package.json` and the committed lockfile already describe the desired dependency tree. The command must not change manifests, lockfiles, package-manager configuration, or build-script approvals.
- Use the repository's originating package manager directly for any dependency-tree change, including adding, removing, updating, deduplicating, or regenerating dependencies or lockfiles. Determine it from the explicit `packageManager`/`devEngines.packageManager` pin and the committed lockfile; if those disagree or are ambiguous, stop and report the conflict.
- Do not use Nub commands that mutate dependency or package-manager state for those changes, including `nub add`, `remove`, `update`, `dedupe`, `import`, `pm use`, `pm pin`, or `approve-builds`.
- If `nub` is unavailable, continue with the repository's existing Node and package-manager tooling. Do not install Nub unless the user explicitly asks.

# Testing

- Write tests that verify semantically correct behavior
- Do not weaken correct tests to make them pass. Report unresolved failures and distinguish existing failures from those introduced by the change.
- **Never** test what the type system already guarantees

# Priority Order

When rules conflict, follow this priority:

1. Correctness and type safety
2. Clarity and maintainability
3. Simplicity (less code over more code)
4. Shipping speed

# Code Quality Standards

- **Never compromise type safety**: No `any`, no non-null assertion operator (`!`), no type assertions (`as Type`)
- **Make illegal states unrepresentable**: Model domain with ADTs/discriminated unions; parse inputs at boundaries into typed structures; if state can't exist, code can't mishandle it
- **Abstractions**: Prefer narrow interfaces over flexible ones. Parameterize only what varies today. Document the *why*, not just the *what*.
- **Never use fallback defaults to mask missing data**: No `?? "unknown"`, no `|| defaultValue` to paper over `undefined` that indicates a bug. If a value can be absent, model it explicitly (e.g., `Option<T>`, nullable field). Fallback values are acceptable only when the fallback is a genuine, documented business default — not a way to silence the type checker.
- **Never add compatibility layers unless explicitly asked**: e.g. when refactoring, replace the old implementation with the new one. Do not leave the old code intact while adding adapters, wrappers, or shims to keep it working. Deprecation paths are only acceptable when explicitly requested.
- **Error handling**: Prefer typed error results (`Result<T, E>`, discriminated unions) over thrown exceptions for expected failure modes. Use `try`/`catch` only for truly unexpected errors at system boundaries.
- **If you touch a file, fix any lint or type issues you find in that file.**

## Testing

- Write tests that verify semantically correct behavior
- **Failing tests are acceptable** when they expose genuine bugs and test correct behavior
- **Never** test what the type system already guarantees

## Git, Pull Requests, Commits

- **Never** add Claude, GitHub, OpenCode to attribution or as a contributor in PRs, commits, messages, or PR descriptions

## Plans

- At the end of each plan, give me a list of unresolved questions to answer, if any. Make the questions extremely concise. Sacrifice grammar for the sake of concision.

## Priority Order

When rules conflict, follow this priority:

1. Correctness and type safety
2. Clarity and maintainability
3. Simplicity (less code over more code)
4. Shipping speed

## Specialized Subagents

### Oracle

Invoke via the host tool's named subagent/task mechanism as `oracle`.

Use for: code review, architecture decisions, debugging analysis, refactor planning, second opinion.

Return format: structured assessment with a clear recommendation and confidence level.

### Librarian

Invoke via the host tool's named subagent/task mechanism as `librarian`, if available in the current host.

Use for: understanding 3rd party libraries/packages, exploring remote repositories, discovering open source patterns.

Return format: summary of findings with relevant code examples and links to source.

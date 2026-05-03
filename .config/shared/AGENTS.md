# Code Quality Standards

- **Never compromise type safety**: No `any`, no non-null assertion operator (`!`), no type assertions (`as Type`)
- **Use small, direct edits**: Prefer the smallest precise edit that solves the problem. Never use `sed` or ad hoc Python/Node scripts to edit files. Re-read the file, adjust the patch, and retry with the proper editing tools.
- **Make illegal states unrepresentable**: Model domain with ADTs/discriminated unions; parse inputs at boundaries into typed structures; if state can't exist, code can't mishandle it
- **Abstractions**: Prefer deep abstractions with small interfaces. Avoid shallow or single-use abstractions. Parameterize only what varies today. Document the *why*, not just the *what*.
- **Prefer the smallest correct change**: The best changes are often the smallest correct changes.
- **When multiple approaches are correct, prefer the more minimal one**: Favor fewer new names, helpers, tests, and moving parts.
- **Never use fallback defaults to mask missing data**: No `?? "unknown"`, no `|| defaultValue` to paper over `undefined` that indicates a bug. If a value can be absent, model it explicitly (e.g., `Option<T>`, nullable field). Fallback values are acceptable only when the fallback is a genuine, documented business default — not a way to silence the type checker.
- **Never add legacy compatibility layers unless explicitly asked**: e.g. when refactoring, replace the old implementation with the new one. Do not leave the old code intact while adding adapters, wrappers, or shims to keep it working. Deprecation paths are only acceptable when explicitly requested.
- **Error handling**: Prefer typed error results (`Result<T, E>`, discriminated unions) over thrown exceptions for expected failure modes. Do not add speculative `try`/`catch` blocks with fallback behavior. Handle real errors explicitly, and otherwise fail clearly rather than masking problems with fallbacks unless explicitly asked.
- **If you touch a file, fix any lint or type issues you find in that file.**

## Testing

- Write tests that verify semantically correct behavior
- **Failing tests are acceptable** when they expose genuine bugs and test correct behavior
- **Never** test what the type system already guarantees

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

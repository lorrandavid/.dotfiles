---
name: scoped-quality-improvement
description: Guidelines for improving code quality only where it directly supports an assigned change. Use when explicitly asked to apply scoped quality improvement or when tightening quality boundaries around a specific implementation.
disable-model-invocation: true
---

# Scoped Quality Improvement

Improve code quality only where it directly supports the assigned change.

Evolve the codebase toward higher quality, but let the assigned task set the
boundary. Do not chase unrelated cleanup.

## Required

- Reuse existing types, utilities, hooks, components, and patterns before adding
  new ones.
- Keep the change as small as possible while preserving correctness and
  readability.
- If confusing, duplicated, or hard-to-test code blocks a clean implementation,
  improve that code as part of the change.
- If a small local cleanup makes the implementation simpler or safer, do it and
  explain it in the PR body.
- If a real quality issue is not needed for the assigned change, leave it for
  review follow-up instead of expanding scope.

## Do Not

- Refactor files only because you opened them.
- Add abstractions for hypothetical future use.
- Rename, move, or reorganize code unless it is necessary for the current
  implementation.
- Broaden public APIs unless the acceptance criteria require it.
- Mix unrelated cleanup into behavioral changes.

---
name: simplify
description: Simplifies recently modified code for clarity, consistency, and maintainability without changing behavior. Use when cleaning up recent changes or simplifying specific files.
argument-hint: "[scope or guidance]"
disable-model-invocation: true
---

This skill delegates code simplification to the `@simplify` agent.

----------------------------------------
WORKFLOW YOU MUST FOLLOW
----------------------------------------

1) Read the user's extra guidance from `$ARGUMENTS`.

2) Determine the simplification scope:
   - If the user names files, symbols, or a broader target, use that scope.
   - Otherwise prefer files changed in the current working tree.
   - If there are no working-tree changes, use the most recent commit as the default scope.

3) Invoke ONE (1) `@simplify` subagent with:
   - user_guidance: the raw `$ARGUMENTS`
   - scope: the resolved files or commit range
   - instruction: preserve exact behavior while improving clarity and maintainability

4) Return the subagent's response directly as the final output.

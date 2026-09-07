---
name: create-commit
description: 'Write concise Conventional Commit messages from staged changes, focused on the final outcome and why it matters.'
disable-model-invocation: true
---

## Scope and workflow

Write a commit message for the staged changes. Generating a message does not itself authorize staging files, creating a commit, or pushing.

1. Run `git status --short`, `git diff --cached --name-only`, and `git diff --cached`. Describe only the staged changes, including only staged hunks of partially staged files. If nothing is staged, report that and stop.
2. Read surrounding code when needed to understand the outcome and motivation. Do not invent issue context, performance gains, or behavior that the diff and available context do not support.
3. Confirm the commit type and scope with the user before finalizing the message, unless they already supplied or confirmed them in this conversation. Inspect the current branch with `git branch --show-current`; if it contains an apparent work-item number (e.g., `feature/123-description`), suggest `#123` as the scope. Available commit types:
   - feat: for new features
   - fix: for bug fixes
   - docs: for documentation changes
   - style: for changes that do not affect the meaning of the code (whitespace, formatting, etc.)
   - refactor: for code changes that neither add features nor fix bugs
   - test: for adding or modifying tests
   - chore: for maintenance tasks and other changes that do not affect the source code or tests
   - task: for work items that do not clearly fit into any of the conventional commit types above

## Writing the message

Use `type(scope): imperative description`. Keep the entire title within 50 characters, including the type and scope. Start the description with an imperative verb and name the concrete change.

Use a title alone when it fully explains a small change. Otherwise, leave a blank line and add a few concise bullets:

- Explain the final behavior and why it is needed. A concrete trigger and before/after outcome often communicates more than an implementation inventory.
- Include implementation details only when they explain a consequential decision, constraint, or tradeoff. Use code names or a short example when they make the explanation clearer.
- Describe the final aggregate change. Omit abandoned approaches, intermediate refactors, commit shuffling, and commentary about how much the diff shrank.
- Omit routine test-run reports, validation checklists, and claims such as "all tests pass." For a test-focused change, describe the behavior now covered. This writing rule does not waive required checks or reporting failures separately to the user.
- Do not repeat the title or require Summary, Motivation, or Technical Description headings. Expand the body only when a complex or high-risk change needs more explanation for a future maintainer.

For larger changes, include review aids when they make the behavior easier to trace. Prefer a precise diagram, snippet, or call stack over paragraphs describing the same thing; choose the useful forms rather than including all of them:

- Use a fenced `mermaid` flowchart or sequence diagram to explain interactions, branching, or runtime hops. Keep labels meaningful even when viewed as plain text.
- Use language-tagged code blocks for changed contracts, important logic, or a small usage example. Keep excerpts focused and label pseudocode explicitly.
- Use a typed call stack to trace the relevant entrypoint through parsing, domain/service calls, adapters, side effects, and the returned result. Show actual function/module names, the order of calls, and the important input, output, and error types crossing each boundary. Use a fenced `text` block for the trace. Include before/after flows or failure paths when they clarify what changed.

Ground these aids in the staged implementation and its surrounding code. Describe the implemented result, not a proposed architecture, and omit unaffected paths. Simple changes need no diagram, snippet, or call stack; larger changes deserve enough detail to support later review without repeating the same information in prose.

If measured performance results matter, summarize the supplied baseline and result with units and conditions; never invent measurements.

For breaking changes, add `!` before the colon and a `BREAKING CHANGE:` footer explaining the impact and required migration. Include verified issue references or other required trailers when relevant, separated from the body by a blank line.

Return one ready-to-use message in a fenced `text` block. When the message contains fenced diagrams or snippets, use a longer outer fence (for example, four backticks around triple-backtick blocks) so the complete message remains copyable.

## Examples

Small change:

```text
docs(#123): clarify local setup steps
```

Change that needs context:

```text
fix(#123): reject blank signup emails

- Reject whitespace-only email addresses before submission so they
  cannot reach the API and produce a generic server error.
- Show the validation error beside the email field.
```

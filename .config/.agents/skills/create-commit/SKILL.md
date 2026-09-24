---
name: create-commit
description: 'Generate commit messages following the Conventional Commits specification.'
disable-model-invocation: true
---

## Instructions

Generate commit messages that follow the Conventional Commits specification. Your task is to analyze the recent changes in the codebase and produce an appropriate commit message.

Before creating the commit message, follow these steps:

1. **Analyze the Changes**: Review the recent code changes to understand what was implemented, fixed, or modified.
2. **Check the staged files**: Make sure you only consider files that have been staged for commit by running `git diff --cached --name-only`.
3. **Identify the Commit Type**: **Always ask the user** which commit type and scope should be used. If the current branch contains a number (e.g., `feature/123-description`), suggest that number as the scope using the `#` prefix (e.g., `#123`), but always confirm it with the user. Available commit types:
   - feat: for new features
   - fix: for bug fixes
   - docs: for documentation changes
   - style: for changes that do not affect the meaning of the code (whitespace, formatting, etc.)
   - refactor: for code changes that neither add features nor fix bugs
   - test: for adding or modifying tests
   - chore: for maintenance tasks and other changes that do not affect the source code or tests
   - task: for work items that do not clearly fit into any of the conventional commit types above

Whenever necessary, ask the user for additional information to ensure the commit message is complete and accurate.

Use `git status --short` to obtain a summary of the changes and `git diff --cached` to inspect the staged differences in detail.

## Commit Message Format

**Commit title:**

Create a clear and descriptive title (maximum of 50 characters, including the commit type and scope) that:

- Starts with an imperative verb.
- Includes the scope in parentheses.
- Describes what was implemented or changed.
- Is specific yet concise.

**Commit body:**

### Summary

Provide a brief description of what this commit implements or resolves.

### Motivation and Context

Explain the reason for the changes and the context in which they were made. Include references to related issues or tickets whenever applicable.

### Technical Description

Describe the technical changes made to the code. Explain design decisions, patterns used, and any important considerations for future developers working on this code. **This section must be organized into bullet points.**

## Example Commit Message

```text
feat(#123): add input validation to signup form

### Summary
Adds input validation to ensure user data is valid before submitting the signup form.

### Motivation and Context
Input validation improves the user experience and prevents invalid data from reaching the backend. This implementation resolves issue #123, where users reported problems submitting invalid data.

### Technical Description
- Uses the XYZ library for form validation.
- Implements validation rules for required fields, email format, and passwords.
- Adds user-friendly error messages to guide users.
- Includes unit tests to ensure the validation logic is robust.
```

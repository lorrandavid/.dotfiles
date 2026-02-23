---
name: code-review
description: Review changes with parallel @code-reviewer subagents
---

Review the code changes using TWO (2) @code-reviewer subagents (one using GPT-5.2-Codex High and the other one using Sonnet 4.5) and correlate results into a summary ranked by severity. Use the provided user guidance to steer the review and focus on specific code paths, changes, and/or areas of concern. Once all two @code-reviewer subagents return their findings and you have correlated and summarized the results, consult the @oracle subagent to perform a deep review on the findings focusing on accuracy and correctness by evaluating the surrounding code, system, subsystems, abstractions, and overall architecture of each item. NEVER SKIP ORACLE REVIEW.

Guidance: $ARGUMENTS

Review uncommitted changes by default. If no uncommitted changes, review the last commit. If the user provides a pull request/merge request number or link, invoke the pr-checkout skill to checkout the PR/MR and review the changes in that context.

```
skill({ name: `pr-checkout` })
```

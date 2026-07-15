---
name: cognitive-driven-development-review
description: "Review code, diffs, pull requests, modules, or designs through Cognitive-Driven Development (CDD): minimize avoidable cognitive load, preserve visible essential domain complexity, and use cognitive-complexity metrics as supporting evidence. Use when the user asks for a CDD review, cognitive-load audit, cognitive-complexity review, code-understandability review, or wants code assessed for how hard it is to trace, change, debug, or onboard into."
---

# Cognitive-Driven Development Review

Optimize the total cognitive work required for realistic engineering tasks. Do not equate shorter code, smaller functions, or lower metric scores with better design.

Read [references/cdd-review-rubric.md](references/cdd-review-rubric.md) completely before evaluating code. Treat CDD as an operational software-design strategy informed by Cognitive Load Theory, not as a claim that static code metrics directly measure a person's cognitive load.

## Review workflow

### 1. Establish the review task

- Honor the scope the user names: diff, branch, pull request, files, module, or whole repository.
- When no scope is named, review current staged and unstaged changes. Include untracked source files. If the worktree is clean, ask for a scope instead of silently auditing arbitrary code.
- Resolve and verify any comparison point before reviewing a diff.
- Default the reader to a competent maintainer who knows the language and repository conventions but did not author the change.
- Name one to three realistic reader tasks, such as explaining the main path, changing one rule, diagnosing a failure, or verifying an invariant.
- Read repository instructions, relevant types, callers, tests, and documentation before judging an isolated hunk.

### 2. Trace behavior and gather evidence

- Follow representative behavior end to end. Inspect enough surrounding code to distinguish local awkwardness from an intentional repository pattern.
- Record the working set the reader must coordinate: domain rules, mutable state, branches, invariants, temporal steps, files, modules, and external contracts.
- Compare before and after when reviewing a change. Attribute only cognitive-load regressions introduced or materially worsened by the change, while separately labeling pre-existing hotspots.
- Use an existing repository analyzer or quality report when one is already configured. Do not install a new analyzer merely to obtain a score.
- Report exact Cognitive Complexity values only when a tool produced them or a manual calculation is unambiguous. Otherwise describe the relevant structural signals qualitatively.

### 3. Apply the CDD lenses

Evaluate every reader task through all of these lenses:

1. **Essential task load** — Identify domain elements that truly must interact. Do not penalize unavoidable business or systems complexity; ask whether it is exposed at the right level and grouped into useful chunks.
2. **Extraneous load** — Find mental work created by representation or structure: scattered rules, hidden state, inconsistent vocabulary, deep nesting, temporal coupling, needless indirection, split attention, or leaky boundaries.
3. **Schema support** — Check whether names, types, cohesive modules, canonical flows, examples, and tests help a maintainer form and reuse an accurate mental model.
4. **Local control-flow complexity** — Use Sonar-style Cognitive Complexity or configured equivalents as evidence about nested and interrupted control flow.
5. **Global cognitive load** — Check navigation, call chasing, cross-file working sets, state transitions, and change amplification that function-level metrics miss.

### 4. Test proposed remedies

For each remedy, replay the reader task against the proposed design:

- Prefer deleting avoidable concepts, states, branches, and dependencies over moving them elsewhere.
- Keep related facts together and place a seam where the reader can treat them as one meaningful chunk.
- Preserve essential domain decisions and vocabulary rather than hiding them behind generic abstractions.
- Reject metric gaming. Extracting nested code is not an improvement when it only turns control flow into call chasing.
- Reject local simplifications that increase total navigation, coupling, or change cost.
- Calibrate advice to reader expertise and repository conventions. Familiar, consistent idioms can form useful schemas; novel cleverness usually cannot.

### 5. Apply a finding threshold

Report a finding only when all of the following are present:

- a precise location or bounded cross-file path;
- a concrete reader task;
- the cognitive mechanism increasing difficulty;
- a likely engineering consequence;
- an actionable direction that plausibly lowers total load.

Use these severities:

- **High** — A common or critical task requires a large, fragile working set and is likely to cause mistakes, unsafe changes, or prolonged diagnosis.
- **Medium** — The burden recurs or affects an important path, but the reader can still recover with deliberate tracing.
- **Low** — A localized, evidenced friction has a proportionate remedy. Omit cosmetic preferences and speculative nits.

Do not modify code during a review unless the user explicitly asks for fixes.

## Output contract

Lead with findings, ordered by severity. Use this form:

```markdown
## Findings

### [High] Rule identity is split across three representations
`path/to/file.ts:42` (and related locations)

- Reader task: Add a new eligibility rule.
- Evidence: The maintainer must synchronize the enum, string switch, and registry entry.
- CDD lens: Extraneous load — split attention and change amplification.
- Consequence: A partial update silently creates inconsistent behavior.
- Direction: Make one representation canonical and derive or encapsulate the others.
```

Then include:

```markdown
## CDD assessment

| Dimension | Load | Evidence |
| --- | --- | --- |
| Essential task complexity | Low / Moderate / High / Critical | ... |
| Local control flow | Low / Moderate / High / Critical | ... |
| Navigation and working set | Low / Moderate / High / Critical | ... |
| State and invariants | Low / Moderate / High / Critical | ... |
| Schema formation burden | Low / Moderate / High / Critical | ... |
| Change amplification | Low / Moderate / High / Critical | ... |

## Metrics

State the tool and scope, or say that the assessment is qualitative. Never present an estimated score as measured data.

## What already works

Name specific design choices that reduce total cognitive work.

## Verdict

Use: Pass, Pass with concerns, or Revise. Explain the decision in two or three sentences and name the reader tasks that drove it.
```

If there are no findings, say so explicitly. Still report the assessment, metric provenance, specific strengths, and residual uncertainty.

---
name: angular-style-guide-audit
description: Audits Angular code against the official style guide (https://angular.dev/style-guide), organized as ten principles, and three project principles (complexity budget measured by script, declarative streams instead of subscribe() in components, and splitting large components), and produces a read-only report. Covers file names, feature-based structure, one concept per file, inject(), selectors, input/output names, member order, logic outside the UI, complex templates, protected, readonly, ngClass/ngStyle, handlers, lifecycle hooks, subscribe() in components, component size, and cognitive complexity points per class. Use whenever the user asks to audit, review, check compliance, measure complexity, or "see what is off the standard" in an Angular project, folder, or file, even if they do not mention "style guide" or "audit".
---

# Angular style guide audit

This skill compares Angular code with the official style guide and with three project principles, and delivers a report. It does not change code.

The guide is sorted into principles. Each principle is a short file that holds the guide sections it covers, what to look for, what is not a violation, and the severity. The official text is in `references/style-guide.md`. It is the source of truth: cite its sections by their English titles and use its words when you explain a rule.

## Principles

Read the principle file before you check its rules. Each file is short.

### From the Angular style guide

| Principle | Guide sections it covers |
| --- | --- |
| [consistency-over-convention](references/principles/consistency-over-convention.md) | When in doubt, prefer consistency. **Read first. It filters every other finding.** |
| [name-files-for-their-contents](references/principles/name-files-for-their-contents.md) | Hyphens, `.spec`, identifier match, same name for `.ts`/template/styles |
| [organize-by-feature](references/principles/organize-by-feature.md) | `src`, `main.ts`, related files together, feature areas, one concept per file |
| [inject-dependencies-with-inject](references/principles/inject-dependencies-with-inject.md) | Prefer the `inject` function |
| [choose-names-that-cannot-clash](references/principles/choose-names-that-cannot-clash.md) | Component selectors, directive selectors, member names |
| [keep-components-about-presentation](references/principles/keep-components-about-presentation.md) | Presentation focus, template logic, lifecycle methods |
| [expose-the-minimum](references/principles/expose-the-minimum.md) | `protected`, `readonly` |
| [declare-in-reading-order](references/principles/declare-in-reading-order.md) | Angular properties before methods, lifecycle interfaces |
| [bind-class-and-style-directly](references/principles/bind-class-and-style-directly.md) | `class`/`style` over `ngClass`/`ngStyle` |
| [name-handlers-for-what-they-do](references/principles/name-handlers-for-what-they-do.md) | Event handler names |

### Project principles

These come from the team. They are not in the guide. Never present them as if they came from the guide.

| Principle | Rule |
| --- | --- |
| [complexity-budget](references/principles/complexity-budget.md) | Cognitive complexity (CDD) per class, measured by `scripts/cdd-complexity.mjs` |
| [prefer-declarative-streams](references/principles/prefer-declarative-streams.md) | Avoid `subscribe()` in components and directives |
| [split-large-components](references/principles/split-large-components.md) | Smart/dumb split for large components |

## Scope

Audit the rules in the principles above, the selector, input, and output names the guide cites, and the three project principles. Do not report OnPush, control flow (`@if`/`*ngIf`), signals vs. RxJS outside the context of `subscribe()`, `strict`, `any`, standalone, lazy loading, `core/`/`shared/` folders, or file suffixes as rules. These topics can be good advice, but they are not part of the scope, and mixing them in reduces trust in the report. If you notice a serious problem outside the scope, cite it in one line under "Out of scope", without a severity.

The guide is a set of recommendations, not requirements. Write findings as recommendations ("the guide recommends…"), not as errors.

## Rules for every principle

- **Confirm each finding by reading the code.** A text search finds comments, strings, and generated code. Open the file and confirm before you report. The searches in the principle files are starting points. Use the available search tool (Grep, `rg`).
- **Judgment rules are marked.** Rules with no exact threshold are marked "Judgment" in their principle file. Show the code and explain why it looks wrong.
- **Ignore code that is not part of the project:** `node_modules/`, `dist/`, `.angular/`, `coverage/`, and generated files.
- **Cite the guide section.** A finding names its principle and the guide section, in English, exactly as in the guide.

## Steps

1. **Find the context.**
   1. Find the root (`angular.json` or the Nx `project.json`) and the requested scope. If the user named a folder or file, audit only that, but read the rest when you need context (for example, to learn the project's selector prefix).
   2. Read the `@angular/core` version in `package.json`. It does not change the rules, but it changes the suggested fix: `input()`/`output()` exist from v17.1, `model()` from v17.2, and `inject()` from v14. In a project that lacks the API, the fix says that the version must be updated first.
   3. Find the selector prefix: the `prefix` field in `angular.json` and the most frequent prefix in the selectors.
   4. Find the dominant file-name convention (with or without the `.component` suffix).
   5. Check that the dependencies are installed (`node_modules/typescript` exists at the root). The script in the complexity-budget principle needs them.
2. **Read `consistency-over-convention`.** Apply it as a filter to everything that follows.
3. **Check the guide principles.** Read each principle file and check its rules against the scope.
4. **Run the project principles.** Run the script once. Use its output for `complexity-budget`, `prefer-declarative-streams`, and `split-large-components`.
5. **Assign severity** with the scale below.
6. **Write the report.**

## Severity

The guide does not define severity. Use this scale and explain it in the report. Each principle file lists the severity of its own findings.

- **High:** can cause a real bug or conflict. `ng` prefix, input or output named like a DOM property, a property initialized by Angular that the code overwrites (without `readonly`), nested `subscribe`, a long-lived subscription without finalization.
- **Medium:** harms the structure or the public API. Folders by type, several concepts in one file, logic outside the UI in a component, public template members, selector without a prefix, file whose name does not match the class, class above the CDD limit, large component without a smart/dumb split, `subscribe` that stores or derives state.
- **Low:** readability and consistency. `inject()`, member order, `ngClass`/`ngStyle`, handler names, lifecycle hooks, missing `implements`, missing `readonly` without reassignment.

## Report

Write in English, unless the user asks for another language. Use short sentences and the active voice. Use this template:

```markdown
# Angular style guide audit: <project or scope>

## Summary

- Angular <version>. Scope: <folders/files>. Selector prefix: `<prefix>`. Naming convention: <with/without suffix>.
- Findings: <n> high, <n> medium, <n> low.
- <One or two sentences about the main patterns, for example "The project organizes folders by type and uses constructor injection in all services.">

## Findings

### <Principle name>

Severity: <high|medium|low>. <"Judgment." when applicable>

<One sentence with what the guide recommends and why, using the guide's own reason.>

| Guide section | File | Problem | Suggested fix |
|---|---|---|---|
| <section title, as in the guide> | `path/file.ts:line` | <what is in the code> | <concrete change, with new name or destination> |

<Repeat for each principle with findings, from the highest severity to the lowest.>

## Project principles

These rules are not part of the style guide.

### Complexity budget

Script: `cdd-complexity.mjs`, TypeScript <version>, <n> files, limit <n> points per class, config `<file>`. <n> unresolved type warnings.

| Class | Points | Items that weigh the most | Suggested reduction |
|---|---|---|---|
| `path/file.ts:line` Name | <n>/<limit> | <item n (lines)> | <concrete change> |

### Prefer declarative streams

<Table with file:line, situation, severity, and fix. List separately the calls considered necessary, with the reason.>

### Split large components

<For each component: class and template size, and the split proposal with names, template blocks, inputs, outputs, and what stays in the container.>

## Compliant

<Principles and guide sections checked with no findings, in a short list. Include the cases accepted by the "Not a violation" notes, for example "`seat-map.ts` has two components, but they form one concept.">

## Out of scope

<Optional. Serious problems that are not part of the guide, one line each.>

## Next steps

<Suggested order of fixes: high severity first; then structural changes (folders, files), because they change import paths; then the rest. Cite automatic migrations when they exist.>
```

Group by principle, not by file. When the same violation appears in many files (for example, 40 constructors), list all of them in the table if there are up to about 15. Above that, list the 15 most relevant, state the total, and give the search pattern that finds the rest.

End by asking the user whether they want to apply fixes, and which ones.

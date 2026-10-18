---
name: angular-style-guide-audit
description: Audits Angular code against the official style guide (https://angular.dev/style-guide) and three project rules (subscribe in components, large components that need a smart/dumb split, and CDD complexity measured by script), and produces a read-only report. Covers file names, feature-based structure, one concept per file, inject(), selectors, input/output names, member order, logic outside the UI, complex templates, protected, readonly, ngClass/ngStyle, handlers, lifecycle hooks, subscribe() in components, component size, and cognitive complexity points per class. Use whenever the user asks to audit, review, check compliance, measure complexity, or "see what is off the standard" in an Angular project, folder, or file, even if they do not mention "style guide" or "audit".
---

# Angular style guide audit

This skill compares Angular code with the official style guide and with three project rules, and delivers a report. It does not change code.

The official text is in `references/style-guide.md`. Read this file before you start. It is the source of truth: cite its sections by their English titles and use its words when you explain a rule.

## Scope: the guide and the project rules

Audit the rules in the style guide, the selector, input, and output names it cites, and the three project rules in Step 3. Do not report OnPush, control flow (`@if`/`*ngIf`), signals vs. RxJS outside the context of `subscribe()`, `strict`, `any`, standalone, lazy loading, `core/`/`shared/` folders, or file suffixes as rules. These topics can be good advice, but they are not part of the scope, and mixing them in reduces trust in the report. If you notice a serious problem outside the scope, cite it in one line under "Out of scope", without a severity.

Keep the report sections separate: findings from the guide cite the guide section; findings from the project rules cite the project rule. Never present a project rule as if it came from the guide.

The guide is a set of recommendations, not requirements. Write findings as recommendations ("the guide recommends…"), not as errors.

## Interpretation rules

These rules prevent the most common false positives.

- **File consistency beats the guide.** The section "When in doubt, prefer consistency" says that a file must not mix conventions. Do not recommend changing a single member of a file to the guide's style if the rest of the file follows another style. Recommend the whole file, or nothing.
- **Type suffixes are not violations.** The guide asks that the file name reflect the identifier inside it. `UserProfileComponent` in `user-profile.component.ts` complies, as does `UserProfile` in `user-profile.ts`. Report only when the name does not match the class (for example, `PaymentFormComponent` in `checkout.component.ts`). If the project mixes both conventions, report it once as an inconsistency.
- **Several components in one file can be correct.** "One concept per file" accepts small classes that form a single concept. Report only when the classes are unrelated or the file is large. When in doubt, the guide prefers smaller files: report it as low and explain.
- **`handleKeydown` can be correct.** The guide accepts a generic name when the handler is long and delegates to methods with specific names.
- **`@Input()` without `readonly` is correct.** The `readonly` rule applies to `input()`, `model()`, `output()`, signal queries and, in the decorator API, only to `@Output` and queries.
- **Judgment rules are marked.** "Avoid overly complex logic in templates", "Keep components and directives focused on presentation", and "Keep lifecycle methods simple" have no exact threshold. Show the code, explain why it looks complex, and mark the finding "Judgment".
- **Confirm each finding by reading the code.** A text search finds comments, strings, and generated code. Open the file and confirm before you report.
- **Ignore code that is not part of the project:** `node_modules/`, `dist/`, `.angular/`, `coverage/`, and generated files.

## Step 1: Context

1. Find the root (`angular.json` or the Nx `project.json`) and the requested scope. If the user named a folder or file, audit only that, but read the rest when you need context (for example, to learn the project's selector prefix).
2. Read the `@angular/core` version in `package.json`. It does not change the rules, but it changes the suggested fix: `input()`/`output()` exist from v17.1, `model()` from v17.2, and `inject()` from v14. In a project that lacks the API, the fix says that the version must be updated first.
3. Find the selector prefix: the `prefix` field in `angular.json` and the most frequent prefix in the selectors.
4. Find the dominant file-name convention (with or without the `.component` suffix).
5. Check that the dependencies are installed (`node_modules/typescript` exists at the root). The script in Step 3 needs them.

## Step 2: Check the rules

For each rule, the table shows what to look for. The searches are starting points. Use the available search tool (Grep, `rg`) and confirm each result by reading the file.

### Naming

| Guide section | What to look for |
|---|---|
| Separate words in file names with hyphens | `.ts`, `.html`, `.css`, and `.scss` files with camelCase, PascalCase, or `_` in the name. |
| Use the same name for a file's tests with `.spec` at the end | Tests with `.test.ts` or with a name different from the tested file. |
| Match file names to the TypeScript identifier within | Main class with a name different from the file. Generic files: `utils.ts`, `helpers.ts`, `common.ts` (with or without a folder prefix). |
| Use the same file name for a component's TypeScript, template, and styles | `templateUrl`/`styleUrl(s)` that point to names different from the `.ts` file. Extra style file without a word that describes its content. |

### Project structure

| Guide section | What to look for |
|---|---|
| All the application's code goes in a directory named `src` | UI code outside `src/`. |
| Bootstrap your application in a file named `main.ts` directly inside `src` | `bootstrapApplication`/`bootstrapModule` outside `src/main.ts`. |
| Group closely related files together in the same directory | Template or style in a different folder from the `.ts` file. A `tests/` or `__tests__/` folder with tests for code in other folders. |
| Organize your project by feature areas | Folders by type: `components/`, `directives/`, `services/`, `pipes/`, `models/`, `guards/`, `interceptors/`. Folders with so many files that they are hard to navigate (count the files and cite the number). |
| One concept per file | Files with more than one `@Component`/`@Directive`/`@Injectable`/`@Pipe`. Decide by the interpretation rules above. |

### Dependency injection

| Guide section | What to look for |
|---|---|
| Prefer the `inject` function over constructor parameter injection | `constructor(` with `private`/`public`/`protected`/`readonly` parameters, or with `@Inject(...)`, in Angular classes. Cite the automatic migration: `ng generate @angular/core:inject`. |

### Components and directives

| Guide section | What to look for |
|---|---|
| Choosing component selectors | Element selector without a hyphen. Prefix different from the project prefix. The `ng` prefix (high severity: the guide says "Never"). |
| Choosing directive selectors | Directive without the project prefix. Attribute selector not in camelCase (`[mr-tooltip]` instead of `[mrTooltip]`). |
| Naming component and directive members | Inputs or outputs named like a DOM property or event (`click`, `change`, `focus`, `blur`, `submit`, `input`, `title`, `hidden`, `id`, `style`, `value` on elements that already have them). Inputs/outputs with a prefix (`appValue`). Outputs with an `on` prefix (`onSave`) or not in camelCase. A name clash with a DOM event is high severity, because the native event also fires the handler. |
| Group Angular-specific properties before methods | Injections, inputs, outputs, or queries declared after methods or mixed in among them. |
| Keep components and directives focused on presentation | Form validation, data transformation, or business rules inside the component that do not depend on the UI. Suggest the destination: pure function, validator, or service. Judgment. |
| Avoid overly complex logic in templates | Expressions with several operators, nested ternaries, call chains, or calculations in the template. Suggest a `computed()` (or a getter, if the project does not use signals). Judgment. |
| Use `protected` on class members that are only used by a component's template | Members without a modifier or with `public` that are used in the template and not used from outside (search for the name in other files before you report). Does not apply to inputs, outputs, and models, which are the public API. |
| Use `readonly` for properties that shouldn't change | `input()`, `input.required()`, `model()`, `output()`, `viewChild()`, `viewChildren()`, `contentChild()`, `contentChildren()`, `@Output()`, `@ViewChild(ren)`, `@ContentChild(ren)` without `readonly`. |
| Prefer `class` and `style` over `ngClass` and `ngStyle` | `[ngClass]`, `[ngStyle]`, `NgClass`, or `NgStyle` in `imports`. |
| Name event handlers for what they _do_, not for the triggering event | Handlers such as `handleClick`, `onClick`, `onSubmit`, `onChange`, `clicked`. Accept generic names when the handler delegates by event type. |
| Keep lifecycle methods simple | `ngOnInit`, `ngOnChanges`, `ngAfterViewInit`, and other hooks with long logic instead of calls to methods with clear names. Judgment. |
| Use lifecycle hook interfaces | Class with `ngOnInit`, `ngOnDestroy`, `ngOnChanges`, and so on, without the matching `implements`. |

## Step 3: Check the project rules

These rules are not in the guide. They come from the team, and they use the script `scripts/cdd-complexity.mjs` to get exact numbers.

### Run the script

```sh
node <skill>/scripts/cdd-complexity.mjs <project-root> [--config <file>] [--json] [<folder-or-file> ...]
```

- Without paths, the script analyzes `src/`. For a smaller scope, pass the requested folders or files (relative to the root).
- The default configuration is `scripts/cdd.config.json`: a limit of 14 points per class, ignored globs, the weight of each item, and the component size limits. If the project has its own `cdd.config.json` at the root, pass it with `--config`.
- The script uses the TypeScript compiler and the type checker of the project itself. So `loop` counts `map`/`forEach` only when the receiver is really an array, `Map`, or `Set`, and `project-coupling` resolves `tsconfig` aliases. If TypeScript is not installed, the script stops with an error. In that case, ask the user to install the dependencies. Do not estimate the points by hand: the purpose of the rule is an exact number.
- "type ... is unresolved" warnings indicate calls the script did not count because the type was not resolved (for example, `any`). Cite the total number of warnings in the report.
- Use `--json` when you need details (the lines of each point). The table output already shows points, lines per item, coupled types, class and template size, and `subscribe()` lines.

### Cognitive complexity (CDD)

Each class accumulates points for the items in the configuration: `if`/`else if`, `case`, ternary, `&&`/`||`, loops and iteration methods, `try/catch`, lambdas with a block body passed as an argument, and each project type the class references (counted once per type). Code outside classes appears as "(file scope)".

- Report each class above the limit, with the total and the breakdown per item. Medium severity.
- For each one, read the code and suggest reductions tied to the items that weigh the most. For example: many coupled types indicate too many responsibilities (split the class); loops and lambdas with bodies indicate data transformation (extract pure functions); chained `if` statements indicate a decision rule (extract it or use a case map).
- The points do not include the template. Template complexity is covered by the guide section "Avoid overly complex logic in templates".

### Avoid `subscribe()` in components and directives

The script lists the `subscribe()` lines in classes with `@Component` or `@Directive`. Services are not part of this rule. Read each call and classify it:

| Situation | Severity | Fix |
|---|---|---|
| `subscribe` inside another `subscribe` | high | Chain with `switchMap`, `concatMap`, `mergeMap`, or `exhaustMap`, depending on the semantics. |
| Long-lived stream (route, `valueChanges`, `interval`, store, `fromEvent`) without `takeUntilDestroyed()`, `async`, or other finalization | high | Memory leak. Replace it with `toSignal()` or `async`. If the subscription is really needed, use `takeUntilDestroyed()`. |
| Result stored in a field for the template to display | medium | `toSignal()` or the `async` pipe. To load data from a parameter, consider `rxResource`/`httpResource` if the project version has these APIs (check whether they are still experimental in that version). |
| State derived from another observable inside `subscribe` | medium | `computed()` over `toSignal()`, or operators in `pipe()`. |
| Route parameter read with `subscribe` | medium | `toSignal(route.paramMap)` or route inputs (`withComponentInputBinding`). |

The rule is "avoid unless strictly necessary". Consider a call necessary, and list it under "Compliant", when it triggers an imperative side effect from a user action without storing a value for the template, and the stream completes on its own (for example, `save()` with HTTP on a click), or when it integrates an imperative third-party API with no declarative alternative. Explain the reason in each case.

`toSignal()` and `takeUntilDestroyed()` exist from v16. In an earlier version, suggest the `async` pipe or `takeUntil` with `ngOnDestroy`.

### Avoid components that are too large (smart/dumb)

The script flags components whose class or template exceeds the `componentLimits` values (default: 200 class lines, 150 template lines). Also consider a component large when it exceeds the CDD limit.

For each large component, look for the split between:

- **Smart (container):** injects services or stores, loads data, handles routes, and holds the state. Has a short template that composes child components.
- **Dumb (presentation):** receives data through inputs, reports actions through outputs, does not inject data services, and can be reused or tested without mocks.

Signs of an opportunity: the component injects data services and also has a long template; template blocks that repeat or sit inside `@for`/`*ngFor` with a large body; independent visual sections (header, filters, list, detail, form); methods used by only one part of the template.

The suggestion must be concrete: the name of each new component, the template block (with line numbers) that moves to it, its inputs and outputs, and what stays in the container. Medium severity. If the component is large but already presentation-only, with no natural split, record it as an observation, not as a finding.

## Step 4: Severity

The guide does not define severity. Use this scale and explain it in the report:

- **High:** can cause a real bug or conflict. `ng` prefix, input or output named like a DOM property, a property initialized by Angular that the code overwrites (without `readonly`), nested `subscribe`, a long-lived subscription without finalization.
- **Medium:** harms the structure or the public API. Folders by type, several concepts in one file, logic outside the UI in a component, public template members, selector without a prefix, file whose name does not match the class, class above the CDD limit, large component without a smart/dumb split, `subscribe` that stores or derives state.
- **Low:** readability and consistency. `inject()`, member order, `ngClass`/`ngStyle`, handler names, lifecycle hooks, missing `implements`, missing `readonly` without reassignment.

## Step 5: Report

Write in English, unless the user asks for another language. Use short sentences and the active voice. Use this template:

```markdown
# Angular style guide audit: <project or scope>

## Summary

- Angular <version>. Scope: <folders/files>. Selector prefix: `<prefix>`. Naming convention: <with/without suffix>.
- Findings: <n> high, <n> medium, <n> low.
- <One or two sentences about the main patterns, for example "The project organizes folders by type and uses constructor injection in all services.">

## Findings

### <Guide section, in English, exactly as in the guide>

Severity: <high|medium|low>. <"Judgment." when applicable>

<One sentence with what the guide recommends and why, using the guide's own reason.>

| File | Problem | Suggested fix |
|---|---|---|
| `path/file.ts:line` | <what is in the code> | <concrete change, with new name or destination> |

<Repeat for each section with findings, from the highest severity to the lowest.>

## Project rules

These rules are not part of the style guide.

### Cognitive complexity (CDD)

Script: `cdd-complexity.mjs`, TypeScript <version>, <n> files, limit <n> points per class, config `<file>`. <n> unresolved type warnings.

| Class | Points | Items that weigh the most | Suggested reduction |
|---|---|---|---|
| `path/file.ts:line` Name | <n>/<limit> | <item n (lines)> | <concrete change> |

<If no class exceeds the limit, say so and cite the 3 classes with the most points.>

### `subscribe()` in components

<Table with file:line, situation, severity, and fix. List separately the calls considered necessary, with the reason.>

### Large components (smart/dumb)

<For each component: class and template size, and the split proposal with names, template blocks, inputs, outputs, and what stays in the container.>

## Compliant

<Guide sections and project rules checked with no findings, in a short list. Include the cases accepted by the interpretation rules, for example "`seat-map.ts` has two components, but they form one concept.">

## Out of scope

<Optional. Serious problems that are not part of the guide, one line each.>

## Next steps

<Suggested order of fixes: high severity first; then structural changes (folders, files), because they change import paths; then the rest. Cite automatic migrations when they exist.>
```

Group by guide section, not by file. When the same violation appears in many files (for example, 40 constructors), list all of them in the table if there are up to about 15. Above that, list the 15 most relevant, state the total, and give the search pattern that finds the rest.

End by asking the user whether they want to apply fixes, and which ones.

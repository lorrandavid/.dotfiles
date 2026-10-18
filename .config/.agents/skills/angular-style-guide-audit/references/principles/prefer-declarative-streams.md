# Prefer declarative streams

**Source:** project rule. Not part of the Angular style guide.

Avoid `subscribe()` in components and directives unless it is strictly necessary. A manual subscription needs manual cleanup and hides state from the template. `toSignal()`, the `async` pipe, and operators in `pipe()` do both jobs.

The script `scripts/cdd-complexity.mjs` lists the `subscribe()` lines in classes with `@Component` or `@Directive`. See [complexity-budget](complexity-budget.md) for how to run it. Services are not part of this rule. Read each call and classify it:

| Situation | Severity | Fix |
|---|---|---|
| `subscribe` inside another `subscribe` | high | Chain with `switchMap`, `concatMap`, `mergeMap`, or `exhaustMap`, depending on the semantics. |
| Long-lived stream (route, `valueChanges`, `interval`, store, `fromEvent`) without `takeUntilDestroyed()`, `async`, or other finalization | high | Memory leak. Replace it with `toSignal()` or `async`. If the subscription is really needed, use `takeUntilDestroyed()`. |
| Result stored in a field for the template to display | medium | `toSignal()` or the `async` pipe. To load data from a parameter, consider `rxResource`/`httpResource` if the project version has these APIs (check whether they are still experimental in that version). |
| State derived from another observable inside `subscribe` | medium | `computed()` over `toSignal()`, or operators in `pipe()`. |
| Route parameter read with `subscribe` | medium | `toSignal(route.paramMap)` or route inputs (`withComponentInputBinding`). |

## Necessary calls

Consider a call necessary, and list it under "Compliant", when:

- it triggers an imperative side effect from a user action without storing a value for the template, and the stream completes on its own (for example, `save()` with HTTP on a click), or
- it integrates an imperative third-party API with no declarative alternative.

Explain the reason in each case.

## Version

`toSignal()` and `takeUntilDestroyed()` exist from v16. In an earlier version, suggest the `async` pipe or `takeUntil` with `ngOnDestroy`.

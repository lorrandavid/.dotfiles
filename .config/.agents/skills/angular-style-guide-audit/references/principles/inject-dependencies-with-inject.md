# Inject dependencies with `inject()`

**Guide section:** Prefer the `inject` function over constructor parameter injection

`inject()` has better type inference, works with class fields, and does not need a constructor only to receive services.

## Look for

`constructor(` with `private`/`public`/`protected`/`readonly` parameters, or with `@Inject(...)`, in Angular classes.

## Fix

Replace the parameter with `private readonly x = inject(X)`. Cite the automatic migration: `ng generate @angular/core:inject`. `inject()` exists from Angular v14.

## Severity

Low.

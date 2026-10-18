# Complexity budget

**Source:** project rule. Not part of the Angular style guide.

Each class has a cognitive-load budget. The script `scripts/cdd-complexity.mjs` measures it, so the number is exact. Do not estimate points by hand.

## Run the script

```sh
node <skill>/scripts/cdd-complexity.mjs <project-root> [--config <file>] [--json] [<folder-or-file> ...]
```

- Without paths, the script analyzes `src/`. For a smaller scope, pass the requested folders or files (relative to the root).
- The default configuration is `scripts/cdd.config.json`: a limit of 14 points per class, ignored globs, the weight of each item, and the component size limits. If the project has its own `cdd.config.json` at the root, pass it with `--config`.
- The script uses the TypeScript compiler and the type checker of the project itself. `loop` counts `map`/`forEach` only when the receiver is really an array, `Map`, or `Set`, and `project-coupling` resolves `tsconfig` aliases. If TypeScript is not installed, the script stops with an error. Ask the user to install the dependencies.
- "type ... is unresolved" warnings indicate calls the script did not count because the type was not resolved (for example, `any`). Cite the total number of warnings in the report.
- Use `--json` when you need the lines of each point. The table output already shows points, lines per item, coupled types, class and template size, and `subscribe()` lines.

## What counts

Each class accumulates points for: `if`/`else if`, `case`, ternary, `&&`/`||`, loops and iteration methods, `try/catch`, lambdas with a block body passed as an argument, and each project type the class references (counted once per type). Code outside classes appears as "(file scope)".

The points do not include the template. Template complexity is covered by [keep-components-about-presentation](keep-components-about-presentation.md).

## Report

Report each class above the limit, with the total and the breakdown per item. For each one, read the code and suggest reductions tied to the items that weigh the most:

- Many coupled types: too many responsibilities. Split the class.
- Loops and lambdas with bodies: data transformation. Extract pure functions.
- Chained `if` statements: a decision rule. Extract it or use a case map.

If no class exceeds the limit, say so and cite the 3 classes with the most points.

## Severity

Medium.

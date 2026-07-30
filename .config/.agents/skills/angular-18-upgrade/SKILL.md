---
name: angular-18-upgrade
description: Upgrade an Angular application to Angular 18 through sequential major-version migrations, including Angular Material MDC migration, dependency alignment, tests, and Azure Pipelines Node updates. Use when a project must migrate from Angular 13–17 to Angular 18 or troubleshoot an Angular 18 upgrade.
compatibility: Requires Git, Node.js, npm, and an Angular workspace. Select a Node.js release supported by every Angular major involved in the migration.
---

# Upgrade Angular to 18

Migrate one Angular major at a time. Treat every major as a checkpoint: clean tree, update, inspect migrations, install, validate, then commit. Preserve unrelated user changes.

## 1. Inventory and baseline

Inspect `package.json`, `package-lock.json`, `angular.json`, TypeScript configs, `.npmrc`, pipeline YAML, and the current Git state. Record:

- current Angular, CLI, TypeScript, Node.js, and npm versions;
- application versus published library;
- Angular Material and any `@angular/material/legacy-*` imports;
- TSLint/codelyzer;
- ng-bootstrap, Apollo, ngx-translate, ngx-mask, PDF viewer, and Angular ESLint dependencies;
- available build, test, lint, and start scripts;
- private npm registries and the pipeline's Node version;
- whether the skill-bundled Angular 18 policy manifest exists at `references/most-used-versions-angular-angular-18.json`, including its dependency groups, `overrides`, and every other top-level section.

Use the repository's local CLI (`npx ng version`) rather than requiring a global CLI replacement. Verify the official Angular Update Guide and changelogs for the exact source/target pair before editing.

Establish the baseline with `npm ci` when the lockfile is valid, then run the existing build, test, and lint commands. If the old dependency graph cannot clean-install under the active runtime, preserve the lockfile, record the incompatibility, select a Node version supported by the current Angular major, and retry before falling back to the existing installation. Distinguish pre-existing failures from migration regressions. This step is complete when the current version, conditional branches, validation commands, and baseline results are explicit.

## 2. Protect the work

If the current branch is `develop`, `release`, `master`, or `main`, create a dedicated upgrade branch such as `feature_develop_angular18`. If the working tree contains unrelated changes, ask the user how to preserve them instead of staging them into an upgrade commit.

Keep the existing `node_modules` and lockfile for the first `ng update`. Clean npm's cache only when cache corruption is suspected. Before every `ng update`, ensure the tree is clean with a focused checkpoint commit.

This step is complete when the upgrade runs on a dedicated branch, unrelated work is protected, and `git status --short` is empty.

## 3. Plan runtime compatibility

Angular 18 supports Node.js `^18.19.1`, `^20.11.1`, or `^22.0.0`; an unbounded `>=18.19.1` range is inaccurate because it includes unsupported releases. Confirm the exact ranges in Angular's official version-compatibility table because support can differ across Angular 18 minors. Use npm >=9 as the project baseline and prefer the organization's validated Node release—historically `22.0.0` in the source playbook—for the final environment. Select a supported Node version for each intermediate Angular CLI, then switch to the final runtime after reaching Angular 18.

If the project starts below Angular 13, derive the missing earlier hops from the official Update Guide rather than jumping directly to 14. If it starts above 18, this skill does not apply.

## 4. Migrate sequentially

For each next major `N` through 18:

1. Confirm a clean tree and create the pre-update checkpoint if the preceding work is uncommitted.
2. Run the versioned CLI so the global installation is irrelevant:

   ```bash
   npx @angular/cli@N update @angular/core@N @angular/cli@N
   ```

3. For intermediate majors 14–17, add `--force` only when peer resolution blocks the documented migration. Record the conflicting packages, their expected compatible versions, why bypassing resolution is safe, and how the final graph will remove the bypass. Keep the Angular 18 update free of `--force`.
4. When Material is present, update it separately at the same major. For `N=17`, first satisfy the hard Material gate while Material 16 is still installed:

   ```bash
   npx ng generate @angular/material:mdc-migration
   ```

   Resolve every schematic finding, then run the exhaustive searches in [Material migration](references/angular-18-playbook.md#angular-material-legacy-to-mdc). Only when no legacy imports, symbols, or SCSS mixins remain, install the target Material major:

   ```bash
   npx @angular/cli@N update @angular/material@N
   ```
5. Install dependencies. Use plain `npm install` for Angular 18. For intermediate peer conflicts, use `--force` only with the exception record from step 3; prefer a compatible dependency version over bypassing resolution.
6. Review generated migrations and the diff. Run the narrowest useful checks plus build and tests. Fix regressions before advancing.
7. Close the major checkpoint by proving all of the following:

   - `npx ng version` reports core and CLI at major `N`, with Material also at `N` when present;
   - `git diff` contains only understood migration changes;
   - `package.json` and the lockfile are synchronized;
   - the production build and applicable tests pass, or unchanged baseline failures are documented;
   - `git status --short` is clean after a focused commit such as `chore: upgrade Angular to 16`.

Do not combine major hops or advance through a failed checkpoint. Before declaring Angular 18 complete, prove a plain `npm install` and `npm ci` both succeed without `--force` or `--legacy-peer-deps`. The sequence is complete when Angular core, CLI, and Material (when present) all report major 18 and every intermediate migration has a reviewable checkpoint.

## 5. Finish Angular 18 alignment

- If TSLint or codelyzer is present, migrate with `ng add @angular-eslint/schematics`, verify linting, then remove TSLint packages and `tslint.json`.
- Look for the skill-bundled policy manifest at `references/most-used-versions-angular-angular-18.json`, resolving the path relative to this `SKILL.md`. When present, validate and read the entire JSON before dependency alignment; it is the authoritative organization policy for the final Angular 18 package manifest, not merely a version lookup table.
- Reconcile every top-level section in that policy manifest with the workspace. Apply relevant `dependencies`, `devDependencies`, `peerDependencies`, `optionalDependencies`, `overrides`, `engines`, `packageManager`, and any additional package or tool configuration it defines. Preserve section placement and exact values. Account for every policy key in the final report as applied, already satisfied, inapplicable with a reason, or blocked by a conflict; never silently ignore unknown sections.
- Validate the resulting package graph against package peer requirements and both `npm install` and `npm ci`. A conflict between the policy manifest and the project or official peer requirements is a blocker to report and resolve with the user; do not alter the mandated value or bypass resolution with `--force` or `--legacy-peer-deps`.
- When the bundled policy manifest is absent, continue using official Angular and package peer ranges, state that no internal Angular 18 policy was available, and never invent recommended versions or overrides. The missing optional file does not block the core Angular migration.
- Unless the bundled policy manifest specifies otherwise, apply the repository policy of exact versions in application `dependencies` and `devDependencies`. For a published library, preserve intentional `peerDependencies` ranges unless the manifest or user explicitly requires pinning them.
- Verify TypeScript settings against generated Angular 18 defaults. Expected values commonly include `target: ES2022`, `lib: ["ES2022", "dom"]`, and `moduleResolution: "bundler"`; change only settings valid for this workspace and builder.
- Verify `angular.json` uses a supported Angular 18 builder. Do not replace a working builder merely to match an example.
- Regenerate `package-lock.json` only when it cannot be synchronized normally, then prove both `npm install` and `npm ci` work.
- Switch the local and pipeline runtime to the chosen final Node version. For the documented Azure template, set `nodeJsVersion: '22.0.0'` in `azure-pipelines.yml`.

Load [Known regressions and fixes](references/angular-18-playbook.md) only for dependencies or symptoms found in the project.

## 6. Validate and report

Run, using the repository's actual script names:

1. clean install (`npm ci` when a lockfile exists);
2. lint and type checking;
3. production build;
4. CI test suite;
5. development startup smoke test: launch the server under a bounded timeout, wait for its readiness signal or HTTP response, capture startup errors, and terminate the process cleanly;
6. targeted visual checks for Material MDC components;
7. the relevant Azure pipeline when access and permission are available.

Search once more for `@angular/material/legacy-`, legacy Material SCSS mixins, TSLint/codelyzer, flexible application dependency versions, and stale pipeline Node values. Inspect `.npmrc` keys with token values redacted; never print the file wholesale or expose credentials in logs. Remove temporary diagnostics.

Commit the final focused changes only after validation. Report version hops, migrations performed, dependency decisions, commands and results, unresolved warnings, visual areas requiring human review, and pipeline status. The upgrade is complete only when Angular reports version 18, installs are reproducible, build and tests pass or documented pre-existing failures remain unchanged, Material legacy usage is absent when Material is installed, and the pipeline runtime is aligned.

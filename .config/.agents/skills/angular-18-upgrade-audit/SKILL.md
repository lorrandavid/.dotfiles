---
name: angular-18-upgrade-audit
description: Audit a completed or in-progress Angular 18 migration against the angular-18-upgrade contract and report what is proven, missing, failing, or unverified. Use when verifying an Angular 18 upgrade, reviewing an upgrade branch or PR, checking for skipped ng update migrations, or producing a migration gap report.
---

# Audit an Angular 18 upgrade

Requires Git, Node.js, npm, an Angular workspace, and the adjacent `angular-18-upgrade` skill. Pipeline verification additionally requires access to the CI provider.

Treat this as a forensic audit, not an upgrade run. Preserve the audited workspace: make no source, manifest, lockfile, configuration, Git-history, or remote-system changes. Run mutation-prone commands only in a disposable copy or worktree and remove it afterward. Queue a pipeline only with explicit user approval.

Before auditing, read `../angular-18-upgrade/SKILL.md` completely. It is the canonical acceptance contract; this skill defines how to prove that contract, not a second version of it. Resolve its relative references from the `angular-18-upgrade` directory. Load its regression playbook only for dependencies or symptoms present in the audited workspace.

Use four row statuses throughout:

- **PASS** — direct evidence proves the requirement.
- **FAIL** — direct evidence proves the requirement is unmet.
- **UNKNOWN** — evidence is missing, inconclusive, or could not be collected.
- **N/A** — the requirement does not apply, with a recorded reason.

Absence of evidence is `UNKNOWN`, not `PASS`. A final Angular 18 version or green build alone does not prove that package migrations ran.

## 1. Pin the audit scope and evidence

Default to the current working tree, including staged, unstaged, and relevant untracked files. If the user names a commit, branch, tag, PR, or comparison point, resolve that exact scope before continuing. Ask only when multiple workspaces or an unresolved target make the scope ambiguous.

Record:

- target ref or working-tree state and exact commit SHA when available;
- repository status and unrelated user changes;
- workspace projects and whether each is an application or published library;
- current versions from manifests, lockfile, `npx ng version`, Node.js, and npm;
- scripts, builders, TypeScript configs, `.npmrc` registry shape with credentials redacted, and pipeline runtime configuration;
- Material, TSLint/codelyzer, Angular ESLint, and dependencies named by the canonical contract;
- the pre-upgrade Angular version and intended version hops, derived from package history, a supplied base ref, PR commits, or migration records;
- available checkpoint commits, `ng update` output, migration ledgers, CI runs, visual evidence, and baseline failures.

Do not infer the starting version from the final manifest. If it cannot be established, mark process checks whose applicability depends on it `UNKNOWN`.

This step is complete when the exact audited state, source version or its uncertainty, workspace type, applicable branches, and available evidence are explicit.

## 2. Build the requirement matrix

Translate every applicable requirement in the canonical contract into one matrix row before judging the upgrade. Cover at least:

1. sequential major checkpoints from the established source version through 18;
2. Angular core, CLI, and Material version alignment;
3. every automatically selected, non-optional core, CLI, and Material migration for every traversed range;
4. final dependency policy, peer compatibility, exact-version policy, lockfile synchronization, and reproducible installs;
5. Material legacy-to-MDC cleanup and visual verification when Material is present;
6. TSLint/codelyzer removal and working Angular ESLint when applicable;
7. Angular 18-compatible TypeScript settings and supported builders;
8. local and pipeline Node.js/npm alignment;
9. lint/type-check, production build, tests, bounded startup smoke test, and applicable pipeline evidence;
10. dependency-specific regressions and fixes only where the project uses those dependencies.

Read the entire optional policy manifest from the canonical skill's `references/most-used-versions-angular-angular-18.json` when it exists. Add a row for every top-level section and key, classified as applied, already satisfied, inapplicable with reason, or conflicting. When it is absent, add one `N/A` row stating that official compatibility and package peer ranges govern instead.

For official compatibility facts, use the Angular version compatibility table, Update Guide, and exact package metadata for the audited versions. Do not substitute current latest-version advice for Angular 18 requirements.

This step is complete only when every canonical requirement has a matrix row or an explicit `N/A` reason.

## 3. Reconstruct and verify automatic migrations

For each core, CLI, and Material hop:

1. Establish the exact package `from` and `to` versions from evidence.
2. Resolve the target package's `ng-update.migrations` collection from its `package.json`.
3. Enumerate the migrations the CLI automatically selects for that exact range using the CLI's selection semantics. Exclude optional migrations and separately invoked modernization schematics from this audit unless the user explicitly made them part of the upgrade.
4. Match each applicable migration to captured CLI output, a checkpoint diff, and its validation result. A legitimate no-op still needs execution evidence.
5. When output is absent, use the target-version CLI's documented `--migrate-only --from ... --to ...` procedure only in a disposable environment that faithfully represents the post-hop checkpoint. Capture output and diff. A resulting change is `FAIL` and the diff identifies pending migration work; a proven no-op is `PASS`.
6. If the post-hop checkpoint cannot be reconstructed faithfully or replay cannot run, use `UNKNOWN`; do not claim that current code shape proves historical execution.

Also verify that core/CLI hops were sequential, Material stayed aligned when present, Material's MDC gate occurred before upgrading past 16, Angular 18 was reached without a peer-resolution bypass, and every intermediate bypass has a recorded conflict and final resolution. Squashed history is not itself a failure when equivalent migration evidence exists; it is `UNKNOWN` where it removes the only proof.

Build the migration ledger with package, exact range, migration name/version, optionality, evidence source, changed/no-op result, validation, and status.

This step is complete only when every automatically applicable migration is individually `PASS`, `FAIL`, or `UNKNOWN` and no migration is represented merely by a package version change.

## 4. Verify the final static state

Inspect the audited files and dependency graph for every final-state row. In particular:

- core, CLI, and Material when present resolve to Angular 18-compatible versions;
- the manifest and lockfile agree, peer requirements resolve, and no final dependency depends on `--force` or `--legacy-peer-deps`;
- every applicable policy-manifest key has the exact required value and section placement;
- application dependency pins or published-library peer ranges follow the canonical contract;
- TypeScript options and `angular.json` builders are supported for this workspace rather than copied blindly from defaults;
- Material source and SCSS contain no legacy imports, symbols, mixins, or unresolved schematic findings;
- TSLint, codelyzer, and `tslint.json` are absent when their migration applies, while the actual lint target works;
- local version files, `engines`, package-manager metadata, and pipeline templates agree on a supported runtime;
- dependency-specific fixes preserve intended behavior rather than merely suppressing tests.

Use focused searches that exclude `.git`, dependency trees, build output, caches, and generated reports. Inspect registry configuration through redacted output.

Run plain `npm install`, `npm ci`, and dependency-tree checks without bypass flags in an isolated environment. Start each reproducibility check from the audited manifests and lockfile, capture any generated diff, and distinguish registry/authentication or infrastructure failures (`UNKNOWN`) from graph/lockfile failures (`FAIL`).

This step is complete when every static-state and install row has evidence and a status, and the audited working tree is unchanged.

## 5. Run behavioral validation

Using the repository's actual commands, collect results for:

1. lint and explicit type checking when separate;
2. production build for every applicable project/configuration;
3. the CI test suite;
4. a bounded development-startup smoke test with a readiness signal or HTTP response and clean termination;
5. targeted Material MDC visual evidence for affected components;
6. an existing CI run pinned to the exact audited SHA, or an explicitly approved new run.

A current failure is `FAIL` unless baseline evidence proves the same unchanged failure and the canonical contract permits it to remain documented; record that permitted exception as `PASS` with its baseline evidence. Otherwise, state that attribution is unknown. Warnings that can affect Angular 18 support, runtime behavior, or reproducibility receive their own matrix rows rather than being buried in command output.

This step is complete when each applicable validation has its command, environment, result, status, and baseline attribution, and temporary processes and environments have been cleaned up.

## 6. Report verdict and missing work

Use these verdicts:

- **VERIFIED** — every applicable mandatory row and automatic migration is `PASS`; only justified `N/A` rows remain.
- **INCOMPLETE** — at least one row is `FAIL`.
- **NOT PROVABLE** — no row fails, but at least one mandatory row is `UNKNOWN`.

Report:

1. verdict and audited scope;
2. version path and checkpoint evidence;
3. complete requirement matrix;
4. complete automatic-migration ledger, including no-ops and unknowns;
5. validation commands and results;
6. missing work ordered by dependency, with exact evidence, affected files or migration, remediation action, and the command or observation that will prove closure;
7. unknowns, blocked checks, manual visual checks, and pipeline status;
8. confirmation that the audited workspace was left unchanged.

Keep concrete defects separate from missing proof. If the user asks to repair the upgrade, pass this report's failed and unknown rows to the `angular-18-upgrade` skill as the bounded remediation scope; do not silently turn the audit into an implementation run.

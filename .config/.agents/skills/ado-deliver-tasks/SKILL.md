---
name: ado-deliver-tasks
description: Deliver one, several, the ready frontier, or all approved Azure DevOps Tasks through implementation and linked draft pull requests. Use when Codex must select Task scope, enforce a dependency DAG, run independent Tasks concurrently in isolated worktrees, delegate each Task to the implement skill, create one PR per Task, and stack dependent PRs from published predecessor branches without completing them.
---

# Deliver ADO Tasks to Draft PRs

Run the delivery control plane from the durable Azure DevOps Task graph. Select exactly what the user requested, schedule only eligible Tasks, delegate each Task's coding lifecycle to `$implement`, and publish one reviewable draft PR per Task.

Read [references/delivery-contract.md](references/delivery-contract.md) before creating worktrees, commits, branches, or PRs.

## Compose the supporting skills

- Use `$azure-devops-cli` for all work-item, relation, PR, policy, reviewer, conflict, and link operations.
- Use `$implement` once per selected Task in that Task's isolated workspace. Let it own code exploration, `$tdd`, routine checks, the final relevant suite, `$code-review`, and commits.
- Pass repository standards to `$implement`; include `$coding-standards` for TypeScript repositories.
- Use `$deslop` on each Task diff after `$implement`, then rerun checks affected by cleanup.
- Use `$make-pr-easy-to-review` on each Task PR.
- Use `$fix-merge-conflicts` only when conflict resolution is explicitly in scope.

Do not duplicate `$implement`'s TDD or review procedure here. Own ADO state, selection, scheduling, workspace isolation, stacking, naming, evidence verification, and PR publication here.

## Authority boundary

An explicit request to deliver named Tasks or “all” Tasks under a parent through draft PRs authorizes scoped worktree and branch creation, repository edits through `$implement`, test execution, commits, non-destructive pushes, draft-PR creation, and linking each PR to its Task and parent.

It does not authorize changing acceptance criteria, expanding the selected Task set, transitioning or closing work items, voting, completing or abandoning PRs, bypassing policies, deleting branches or worktrees, or force-pushing rewritten history. Require separate authorization for those actions.

## Workflow

### 1. Reconstruct the delivery source

Read `docs/agents/issue-tracker.md` and repository instructions. Fetch a complete current parent snapshot and every candidate Task's body, revision, relevant comments, relations, state, readiness marker, and related PRs.

Build the verified DAG from native relations and Task bodies. Stop on disagreement or cycles rather than guessing.

### 2. Resolve the requested scope

Interpret selection literally:

- A Task ID or explicit list selects only those Tasks.
- “Frontier” selects currently ready Tasks with no unsatisfied predecessors.
- “All” with a parent selects every agent-ready descendant Task not already delivered, including Tasks that will become eligible later.
- A parent ID without “all,” “frontier,” or Task IDs is ambiguous: show the candidate set and ask which scope to deliver.

Never implement an unselected predecessor merely to unblock a selected Task. If its PR is absent, report the selected Task as blocked. Never add newly discovered Tasks to the selection without user authorization.

### 3. Enforce readiness

Require every selected Task to have a stable parent and accepted revision, observable acceptance criteria, explicit non-goals, agreed public test seams, resolved product decisions, validation expectations, and a valid place in the DAG.

If the parent changed materially after the accepted revision, return to `$ado-plan-requirement`. Treat ADO-recorded seams as pre-agreed for `$tdd`; do not ask the user to reconfirm them.

### 4. Choose names consistently

Choose the Conventional Commit type from the actual change:

- `feat` for new behavior;
- `fix` for a defect;
- `refactor` for behavior-preserving restructuring;
- `perf`, `test`, `docs`, `build`, `ci`, or `chore` when those are the honest primary purpose.

Use the same concise, imperative description across artifacts:

- Every commit subject and the PR title: `<type>(#<ADO_WORK_ITEM_ID>): <brief description>`
- Branch: `<type>/<ADO_WORK_ITEM_ID>-<kebab-description>`
- Worktree directory: `<repository>-wt-<ADO_WORK_ITEM_ID>-<kebab-description>`

Examples: `feat(#4201): revoke active sessions`, `fix(#731): reject expired tokens`, and branch `feat/4201-revoke-active-sessions`.

Use the selected Task or Bug ID, not the parent ID. Do not include `codex`, an agent name, or a harness name. Respect a stricter repository naming convention when one exists, while retaining the work-item ID and Conventional Commit intent.

### 5. Isolate work by default

Unless the user explicitly asks to work by switching branches in the current workspace, create one git worktree per active Task with its own branch. Prefer the repository-configured worktree root; otherwise use a safe sibling directory outside the primary worktree.

Before creation, verify the base ref, destination path, and existing worktrees. Never reuse a dirty or mismatched worktree. Do not remove worktrees automatically after PR creation.

If the user explicitly requests current-workspace branch mode, process Tasks sequentially because one worktree cannot safely host concurrent branches. Concurrent delivery requires separate worktrees or equivalent isolated checkouts.

### 6. Schedule the DAG

Track each selected Task as `pending`, `eligible`, `running`, `pr-published`, `blocked`, or `failed`.

A Task is eligible only when:

- it has no predecessors; or
- each predecessor already has a validated, pushed branch and a created PR that ADO can read back;
- and the stacking rules below yield one unambiguous base branch.

For each scheduling wave:

1. Compute the eligible frontier.
2. Run independent eligible Tasks concurrently when the harness supports isolated workers; give each worker exclusive ownership of its worktree and Task.
3. Invoke `$implement` once per Task.
4. Verify, deslop, push, create, link, and read back that Task's draft PR.
5. Mark `pr-published` only after the PR and branch are verified; then recompute the frontier.

Do not start a dependent Task merely because its predecessor has code or commits. The predecessor's PR must exist and its source branch must be available.

If a Task has one predecessor, base its branch and worktree on the predecessor's published branch and target its PR to that predecessor branch. This is a stacked PR.

If a Task has multiple predecessors, do not invent a synthetic merge. Wait until their PRs are merged into a common base, or use an explicit repository-defined integration-branch strategy authorized by the user.

A failed Task blocks its descendants but not independent branches of the DAG. Continue other eligible work when safe and report the blocked subtree.

### 7. Build one implementation packet per Task

Pass `$implement` only the current Task plus the context it needs:

- parent snapshot, accepted revision, and URLs;
- current Task body, revision, relevant comments, and URL;
- predecessor IDs, PRs, branches, and the chosen base commit;
- acceptance criteria, non-goals, and pre-agreed test seams;
- validation commands, repository instructions, standards, glossary, and ADRs;
- the fixed point for `$code-review`;
- required Conventional Commit subject pattern, PR title, and branch name;
- authority boundaries and prohibited actions.

Require `$implement` to return commits, criterion-level evidence, validation results, separate Standards and Spec review findings, and unresolved items. It must not implement sibling or successor Tasks.

### 8. Verify and publish each Task PR

Compare `$implement`'s result to the Task packet. Require honest check outcomes, an in-scope diff, mapped commits, and resolved or explained review findings.

Run `$deslop`, preserve behavior, and rerun affected checks. Use `$make-pr-easy-to-review` with the delivery contract. Push non-destructively and create a **draft** PR:

- Root Task: source is the Task branch; target is the configured base branch.
- Single-predecessor Task: source is the Task branch; target is the predecessor's published source branch.

Link the PR to the Task and parent with `$azure-devops-cli`. Read back links, policies, reviewers, source/target branches, and server conflict status. Do not delete a source branch while another selected Task is stacked on it.

### 9. Return the delivery record

Return one result for the whole requested selection, with per-Task worktree, branch, base, stack parent, implementation evidence, PR, and scheduler state. Distinguish delivered, blocked, failed, unselected, and already-delivered Tasks.

## Recovery and stopping conditions

- On ambiguous ADO mutation, read server state before retrying.
- On `$implement` failure, preserve that Task's worktree, branch, commits, and evidence; never unlock its descendants.
- On parent drift, invalid dependencies, missing seams, or scope ambiguity, return to planning.
- On local conflicts, report them separately from ADO `mergeStatus`; use `$fix-merge-conflicts` only when authorized.
- On credential or permission failure, preserve local progress and report the exact unpublished branches or PR operations.

Finish when every selected Task is either represented by a verified draft PR or explicitly reported as blocked or failed. Do not approve, complete, abandon, retarget, or transition work items unless separately requested.

---
name: ado-deliver-tasks
description: Deliver one, several, the ready frontier, or all approved Azure DevOps Tasks through implementation and linked draft pull requests. Use when Codex must select Task scope, enforce a dependency DAG, run independent Tasks concurrently in isolated worktrees, delegate coding to the implement skill, gate final Task diffs through Cognitive-Driven Development review and a successful branch pipeline, create one PR per Task, and stack dependent PRs from published predecessor branches without completing them.
---

# Deliver ADO Tasks to Draft PRs

Run the delivery control plane from the durable Azure DevOps Task graph. Select exactly what the user requested, schedule only eligible Tasks, keep each selected Task's ADO state aligned with its actual delivery moment, delegate each Task's coding lifecycle to `$implement`, gate its final diff with `$cognitive-driven-development-review` and the repository's Azure Pipeline, and publish one reviewable draft PR per Task only after both gates pass and its Task-owned history is rebased and squashed to one commit.

Read [references/delivery-contract.md](references/delivery-contract.md) before creating worktrees, commits, branches, queueing pipelines, or creating PRs.

## Compose the supporting skills

- Use `$azure-devops-cli` for all work-item, state-discovery, lifecycle-transition, pipeline, relation, PR, policy, reviewer, conflict, and link operations. Discover states separately for every selected work-item type; never reuse assumed state names across types or projects.
- Use the unchanged `$implement` skill in the current agent session for the initial implementation in each selected Task's isolated workspace. Let it own code exploration, `$tdd`, routine checks, the final relevant suite, `$code-review`, and commits. Invoke it again only through the bounded CDD remediation loop in step 8. Skill invocation is not permission to spawn a model-backed subagent.
- Pass repository standards to `$implement`; include `$coding-standards` for TypeScript repositories.
- Use `$deslop` on each Task diff after `$implement`, then rerun checks affected by cleanup.
- Use `$cognitive-driven-development-review` after cleanup and affected checks. Keep its findings separate from `$code-review`'s Standards and Spec axes.
- Use `$make-pr-easy-to-review` on each Task PR.
- Use `$resolving-merge-conflicts` only when conflict resolution is explicitly in scope.

Do not duplicate or modify `$implement`'s TDD or review procedure here. Own CDD review, ADO state, selection, scheduling, workspace isolation, stacking, naming, evidence verification, and PR publication here.

## Authority boundary

An explicit request to deliver named Tasks or “all” Tasks under a parent through draft PRs authorizes scoped worktree and branch creation, repository edits through `$implement`, test execution, commits, non-destructive pushes, queuing and monitoring the repository's configured validation pipeline for each Task branch, in-scope pipeline remediation through `$implement`, draft-PR creation after a successful run, linking each PR to its Task and parent, routine non-terminal Task state transitions that accurately represent work started, review readiness, or a configured blocked state, one concise blocker or failure discussion comment when no fitting state exists, and removing each clean Task worktree after its PR is published and verified.

It also authorizes rewriting a Task branch only before its PR exists, solely to rebase it onto its verified target and squash its Task-owned history to one commit. When that unpublished branch already exists remotely because a pipeline was run, update it only with `--force-with-lease` pinned to the remote SHA just read back; never use plain `--force`. This narrow authorization ends as soon as the PR is created.

For every successfully published Task, cleanup is part of delivery, not optional follow-up. The delivery request authorizes removing the exact clean Task worktree, its worktree directory, temporary PR-description/evidence files created by this workflow, and stale git worktree administrative records. It does not authorize deleting the local or remote Task branch or recursively deleting an unverified/non-empty directory.

It does not authorize changing acceptance criteria, expanding the selected Task set, closing, completing, removing, or otherwise terminally transitioning work items, voting, completing or abandoning PRs, bypassing policies, deleting branches, force-removing dirty worktrees, or any other force-push or rewritten-history publication. Require separate authorization for those actions.

## Workflow

### 1. Reconstruct the delivery source

Read `docs/agents/issue-tracker.md` and repository instructions. Fetch a complete current parent snapshot and every candidate Task's body, work-item type, revision, relevant comments, relations, state, readiness marker, and related PRs. For each selected work-item type, fetch the project's configured state catalog through `$azure-devops-cli` and record names, categories, and customization metadata.

Build the verified DAG from native relations and Task bodies. Stop on disagreement or cycles rather than guessing.

Resolve the repository's configured pre-PR validation pipeline ID, name, required parameters, and project. Prefer an explicit repository contract. Otherwise discover pipelines associated with the repository through `$azure-devops-cli`; use the sole applicable validation pipeline when unambiguous, and stop for direction when multiple candidates remain. Never guess a pipeline definition or silently substitute a PR-only policy build.

### 2. Resolve the requested scope

Interpret selection literally:

- A Task ID or explicit list selects only those Tasks.
- “Frontier” selects currently ready Tasks with no unsatisfied predecessors.
- “All” with a parent selects every agent-ready descendant Task not already delivered, including Tasks that will become eligible later.
- A parent ID without “all,” “frontier,” or Task IDs is ambiguous: show the candidate set and ask which scope to deliver.

Never implement an unselected predecessor merely to unblock a selected Task. If its PR is absent, report the selected Task as blocked. Never add newly discovered Tasks to the selection without user authorization.

### 3. Enforce readiness

Require every selected Task to have a stable parent and accepted revision, observable acceptance criteria, explicit non-goals, agreed public test seams, resolved product decisions, validation expectations, a resolved pre-PR pipeline, and a valid place in the DAG.

If the parent changed materially after the accepted revision, return to `$ado-plan-requirement`. Treat ADO-recorded seams as pre-agreed for `$tdd`; do not ask the user to reconfirm them.

### 4. Choose names consistently

Choose the Conventional Commit type from the actual change:

- `feat` for new behavior;
- `fix` for a defect;
- `refactor` for behavior-preserving restructuring;
- `perf`, `test`, `docs`, `build`, `ci`, or `chore` when those are the honest primary purpose.

Use the same concise, imperative description across artifacts:

- The single final Task-owned commit subject and the PR title: `<type>(#<ADO_WORK_ITEM_ID>): <brief description>`
- Branch: `<type>/<ADO_WORK_ITEM_ID>-<kebab-description>`
- Worktree directory: `<repository>-wt-<ADO_WORK_ITEM_ID>-<kebab-description>`

Examples: `feat(#4201): revoke active sessions`, `fix(#731): reject expired tokens`, and branch `feat/4201-revoke-active-sessions`.

Use the selected Task or Bug ID, not the parent ID. Do not include `codex`, an agent name, or a harness name. Respect a stricter repository naming convention when one exists, while retaining the work-item ID and Conventional Commit intent.

### 5. Isolate work by default

Unless the user explicitly asks to work by switching branches in the current workspace, create one git worktree per active Task with its own branch. Prefer the repository-configured worktree root; otherwise use a safe sibling directory outside the primary worktree.

Before creation, verify the base ref, destination path, and existing worktrees. Never reuse a dirty or mismatched worktree. After the Task's branch and PR are published and verified, require a clean worktree, remove that exact Task worktree without `--force`, and verify it no longer appears in `git worktree list --porcelain`. Preserve and report a worktree that is dirty or cannot be removed safely.

If the user explicitly requests current-workspace branch mode, process Tasks sequentially because one worktree cannot safely host concurrent branches. Concurrent delivery requires separate worktrees or equivalent isolated checkouts.

### 6. Schedule the DAG

Track each selected Task as `pending`, `eligible`, `running`, `pr-published`, `blocked`, or `failed`. These are delivery scheduler states, not ADO state names.

Synchronize ADO state only at meaningful transitions:

- On entering `running`, select the unambiguous configured `InProgress` state for that Task type and transition before implementation begins.
- While remediation, review, or pipeline work continues, keep the Task in that in-progress state.
- On entering `pr-published`, prefer an explicit configured review state such as “Ready for Review” or “In Review.” If none exists, retain the in-progress state; a draft PR is not completion.
- On entering `blocked`, use an explicit configured blocked/on-hold state when one exists. Otherwise retain the current non-terminal state and add one concise discussion comment with the blocker and recovery condition.
- On entering `failed`, use an explicit configured failed state only when the tracker contract defines it as non-terminal and appropriate for delivery failure. Otherwise retain the current state and add one concise discussion comment with the failure evidence and recovery condition.

Use the repository tracker contract's explicit lifecycle mapping first. Otherwise apply `$azure-devops-cli`'s semantic state-selection protocol. Never guess among equally suitable states, never hop through speculative intermediate states, and never move a Task to a `Completed` or `Removed` category in this workflow. Read back every attempted transition. A state-update permission, rule-validation, ambiguity, or readback failure blocks that Task before further implementation or publication; preserve evidence and continue independent Tasks when safe.

Keep a Task `running` throughout CDD review, pipeline execution, and remediation. Do not invent a separate scheduler state for review or remediation; transition to `blocked` or `failed` only at the stopping conditions below.

A Task is eligible only when:

- it has no predecessors; or
- each predecessor already has a validated, pushed branch and a created PR that ADO can read back;
- and the stacking rules below yield one unambiguous base branch.

For each scheduling wave:

1. Compute the eligible frontier.
2. Process eligible Tasks sequentially in the current agent session by default, while retaining one isolated worktree per Task. Use isolated model-backed workers only when the user explicitly authorizes subagents and the harness proves they will use the exact parent model and reasoning tier.
3. Invoke `$implement` in the current session for the initial implementation of each Task.
4. Verify, deslop, run the CDD gate, perform bounded remediation when required, rebase and squash the Task-owned history to one commit, push the branch, run the pre-PR pipeline against that exact pushed SHA, remediate and repeat the history and validation gates until it succeeds, then create, link, and read back that Task's draft PR.
5. Run the mandatory cleanup procedure for the Task's clean worktree and verify both git deregistration and filesystem removal.
6. Mark `pr-published` only after the successful pipeline run and PR are verified. Track cleanup independently as `removed` or an explicit cleanup failure; then recompute the frontier.

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
- validation pipeline ID, name, project, required parameters, source branch, and exact pushed commit requirement;
- the fixed point for `$code-review`;
- required Conventional Commit subject pattern, PR title, and branch name;
- authority boundaries and prohibited actions.

Require `$implement` to return commits, criterion-level evidence, validation results, separate Standards and Spec review findings, and unresolved items. Its intermediate commits may remain during implementation and remediation, but the delivery controller must squash them before publication. It must not implement sibling or successor Tasks.

Build the CDD review brief separately; do not require `$implement` to invoke or understand the CDD skill. Include:

- the fixed base commit and the complete Task diff scope, including committed, staged, unstaged, and untracked source changes;
- the default reader persona or a Task-specific reader named by the requirement;
- one to three reader tasks derived from acceptance criteria, such as changing the primary rule, diagnosing the most important failure mode, or verifying the main invariant;
- relevant acceptance criteria, non-goals, repository instructions, glossary, ADRs, types, tests, and analyzer output already available in the repository.

If CDD requires remediation in step 8, build a bounded remediation packet for the unchanged `$implement` skill. Pass the exact CDD findings, locations, reader tasks, consequences, recommended directions, validation commands, and the original Task's scope boundaries. Prohibit sibling work, speculative refactors, and changes that violate acceptance criteria or non-goals.

### 8. Verify, pass the pipeline, and publish each Task PR

Compare `$implement`'s result to the Task packet. Require honest check outcomes, an in-scope diff, mapped commits, and resolved or explained review findings.

Run `$deslop`, preserve behavior, and rerun affected checks. Then invoke `$cognitive-driven-development-review` against the complete final Task diff from the fixed base commit through `HEAD` and the current worktree state. Keep Standards, Spec, and CDD as separate evidence axes.

Apply this CDD gate only to findings introduced or materially worsened by the Task:

- **Pass** — continue to publication.
- **Pass with concerns** — continue only when no introduced High finding remains; record every unresolved concern in the delivery evidence and draft PR.
- **Revise**, or any introduced High finding — do not publish or unlock descendants. Invoke the unchanged `$implement` skill in the same Task worktree with the bounded remediation packet, then verify scope, rerun affected and final checks, rerun `$deslop`, and rerun CDD.

Allow at most two CDD remediation rounds per Task. If the final result is still **Revise** or retains an introduced High finding, mark the Task `failed`, preserve its worktree, branch, commits, CDD evidence, and validation results, and keep its descendants blocked. If remediation would conflict with accepted requirements or non-goals, mark the Task `blocked` and return it to requirement planning instead of expanding scope. Record pre-existing CDD findings separately and do not block on them unless the Task worsened them.

Append every CDD attempt and remediation result to the delivery evidence; never overwrite the initial finding set with the final pass.

After the CDD gate passes, use `$make-pr-easy-to-review` with the delivery contract to prepare reviewer guidance and finalize history. Fetch and read back the intended target branch, rebase the Task branch onto that exact target head, and squash all commits in the Task-owned range `target-head..HEAD` to exactly one commit with the required subject. For a stacked PR, the target is the predecessor's published source branch; do not squash or rewrite predecessor commits. Verify the resulting range contains one commit, the target head is an ancestor of `HEAD`, the worktree is clean, and the diff still matches the reviewed Task diff. If the rebase changes the effective diff or requires conflict resolution, rerun affected and final checks, `$deslop`, Standards and Spec review, and the CDD gate; do not silently resolve conflicts outside the authorized conflict workflow.

Include the CDD verdict, reader tasks, metric provenance, and unresolved concerns in the prepared PR description; add the final pipeline evidence only after the exact-SHA run succeeds.

Push and verify the remote Task branch resolves to the expected local `HEAD`. Use a normal push when it is a fast-forward or the branch is new. If pre-PR squashing or rebasing rewrote an already-pushed pipeline branch, first read its remote SHA and use `--force-with-lease=<branch>:<observed-sha>`; abort on lease failure or ambiguous remote state. Never rewrite a branch after its PR exists. Queue the configured pipeline through `$azure-devops-cli` with both the Task branch and that exact commit SHA. Capture the run ID returned by the queue operation; on an ambiguous response, inspect server state for an exact pipeline, branch, and source-version match before retrying because queuing a run is non-idempotent.

Poll that run to a terminal state without opening a PR. Accept only `status: completed` with `result: succeeded`. Treat `partiallySucceeded`, `failed`, and `canceled` as non-passing.

For each non-passing run:

1. Append the run ID, URL, pipeline definition, branch, source SHA, status, result, timeline issues, and relevant failed-step logs to the Task's delivery evidence.
2. Distinguish an actionable code or repository-pipeline failure from infrastructure, permission, unavailable-agent, cancellation, or external-service failure.
3. For an actionable in-scope failure, invoke the unchanged `$implement` skill in the same Task worktree with a bounded pipeline-remediation packet containing the exact failed steps, errors, relevant logs, failing SHA, original acceptance criteria, non-goals, and validation commands.
4. Verify the remediation stays within the Task, require `$implement` to commit it, rerun affected and final local checks, rerun `$deslop`, rerun Standards and Spec review through `$implement`, and rerun the CDD gate.
5. Run `$make-pr-easy-to-review` again, re-fetch the target, rebase if needed, and re-squash the complete Task-owned range to exactly one commit. Re-verify ancestry, commit count, subject, clean state, and reviewed diff; then update the unpublished remote branch using the lease-protected rule above, verify the new remote SHA, and queue a new pipeline run pinned to it.

Repeat without an arbitrary retry cap while each failure yields an actionable in-scope remediation and measurable progress. Never reuse a successful result from an older SHA. If remediation would expand scope, violate accepted requirements or non-goals, or cannot address an infrastructure, authentication, permission, agent-capacity, cancellation, or external-service failure, mark the Task `blocked`, preserve its worktree and evidence, and do not create a PR.

Append the successful terminal run to the evidence. Verify its `sourceBranch` and `sourceVersion` equal the Task branch and current remote `HEAD`. Add that run's ID, URL, definition, source SHA, and result to the prepared PR description without changing branch contents or history.

Immediately before PR creation, fetch and read back the target branch again. Verify it still resolves to the target head used by the rebase, `target-head..HEAD` still contains exactly one Task-owned commit with the required subject, local `HEAD` equals the remote source SHA, and the successful pipeline ran for that exact SHA. If the target moved, rebase and squash again, repeat every affected review/check gate, update the unpublished remote branch with the lease-protected rule, and obtain a new successful exact-SHA pipeline run. Do not create the PR until all of these conditions hold.

Render the complete PR description as Markdown with real line breaks in a temporary `.md` file outside the Task worktree. Pass the file's contents as one quoted CLI argument; never flatten the Markdown, join its lines with spaces, or pass literal `\n` escape sequences. Inspect the rendered file before creation and remove it after the final PR readback. Only then create the **draft** PR:

- Root Task: source is the Task branch; target is the configured base branch.
- Single-predecessor Task: source is the Task branch; target is the predecessor's published source branch.

Link the PR to the Task and parent with `$azure-devops-cli`. Read back the title and description as well as links, policies, reviewers, source/target branches, and server conflict status. Verify the server description retains the required Markdown headings and actual line breaks; repair and re-read it before publication is considered successful if it was escaped or flattened. Do not delete a source branch while another selected Task is stacked on it.

After that readback succeeds, synchronize the Task to the configured review-ready state according to step 6 and read it back. If no explicit review state exists, verify that its current state remains non-terminal and accurately in progress.

Then run this mandatory cleanup procedure before returning the overall delivery result:

1. Remove workflow-created temporary files. Verify the Task worktree has no staged, unstaged, or untracked changes with both `git status --porcelain` and an explicit untracked-file check.
2. Resolve and record the exact absolute Task worktree path. Confirm it matches the path created for this Task and appears in `git worktree list --porcelain`; never operate on the primary worktree or an unverified path.
3. From outside that worktree, run `git worktree remove <absolute-task-worktree-path>` without `--force`.
4. Verify the path is absent from `git worktree list --porcelain` **and** no longer exists on the filesystem. A successful git exit code alone is insufficient.
5. Run `git worktree prune`, inspect the worktree list again, and verify no stale administrative entry remains for the exact path.
6. If git has deregistered the worktree but the exact directory still exists, inspect it. Remove it with `rmdir` only when it is empty; never use `rm -rf`. Reverify filesystem absence.
7. Keep the local and remote Task branches. Record cleanup as `removed` only after every verification passes.

After processing all selected Tasks, perform a final cleanup sweep over every Task that reached `pr-published`, including Tasks published earlier in the run. Re-run the git-list and filesystem checks for each original path and retry the safe cleanup procedure when necessary. Do not claim the overall delivery is fully complete while a published Task worktree remains registered or its directory remains on disk. If a worktree is dirty, its path is unsafe or ambiguous, or safe removal still fails, preserve it, keep the Task `pr-published`, set the cleanup result to `preserved-dirty` or `removal-failed`, and prominently report the exact path, status output, and removal error.

### 9. Return the delivery record

Return one result for the whole requested selection only after the final cleanup sweep, with each Task's original worktree path, whether that path still exists, whether git still registers it, cleanup commands/results, cleanup result, branch, base, stack parent, final rebased target SHA, squashed commit SHA and subject, implementation evidence, every pipeline attempt and the final exact-SHA result, separate Standards, Spec, and CDD evidence, remediation rounds, PR, scheduler state, and ADO lifecycle record. The lifecycle record must include the work-item type, discovered states, each delivery moment, previous/selected/final state, selection rationale, and readback verification. Distinguish delivered, blocked, failed, unselected, and already-delivered Tasks.

## Recovery and stopping conditions

- On ambiguous ADO mutation, read server state before retrying.
- On `$implement` failure, preserve that Task's worktree, branch, commits, and evidence; never unlock its descendants.
- On exhausted CDD remediation, preserve the Task artifacts and final review evidence, mark the Task `failed`, and never unlock its descendants.
- On a non-passing pipeline with an actionable in-scope cause, keep remediating and rerunning the complete post-change validation sequence until the exact pushed SHA succeeds.
- On a pipeline blocked by infrastructure, authentication, permission, agent capacity, cancellation, external service, missing logs, or ambiguous definition, preserve the worktree and all run evidence, mark the Task `blocked`, and never create its PR or unlock its descendants.
- On a CDD remedy that conflicts with acceptance criteria, non-goals, or the accepted parent revision, stop remediation and return to planning.
- On parent drift, invalid dependencies, missing seams, or scope ambiguity, return to planning.
- On local conflicts, report them separately from ADO `mergeStatus`; use `$resolving-merge-conflicts` only when authorized.
- On post-publication worktree cleanup failure, retry during the final cleanup sweep. If safe removal still fails, preserve the worktree, keep the Task `pr-published`, classify the overall result as delivered-with-cleanup-failures rather than fully complete, and report its exact path, filesystem existence, git registration, cleanliness, and removal error. Never use `git worktree remove --force` or `rm -rf`.
- On a pre-PR rebase conflict, target movement, lease failure, or history-verification failure, do not open the PR. Preserve local progress and report the exact target/source SHAs and recovery action.
- On credential or permission failure, preserve local progress and report the exact unpublished branches or PR operations.
- On lifecycle-state ambiguity, absence of a required work-started state, transition rejection, or failed readback, preserve the current server state and Task artifacts, mark the Task `blocked`, and report the candidate states and recovery action. Never compensate by selecting a terminal state.

Finish when every selected Task is either represented by a verified draft PR or explicitly reported as blocked or failed, and the final cleanup sweep has run. A published Task is cleanly finished only when its exact worktree path is absent from both git's worktree registry and the filesystem; otherwise return delivered-with-cleanup-failures. Do not approve, complete, abandon, retarget, or terminally transition work items. Perform only the verified non-terminal lifecycle transitions authorized above.

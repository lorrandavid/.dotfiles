---
name: ado-plan-requirement
description: Turn an Azure DevOps Feature or User Story into an approved, agent-ready graph of child Tasks. Use when Codex must gather complete requirement history, inspect the codebase, clarify or grill ambiguities, define acceptance criteria and test seams, decompose work into dependency-ordered vertical slices, and optionally publish and verify the Tasks in Azure DevOps.
---

# Plan an ADO Requirement

Produce the durable planning half of delivery. Treat the Azure DevOps requirement and its history as the source record, then make the published Task graph sufficient for a fresh agent to implement without this conversation.

Read [references/task-contract.md](references/task-contract.md) before drafting or publishing Tasks.

## Compose the supporting skills

- Use `$azure-devops-cli` for every Azure DevOps read or mutation and follow its classifications, pagination, URL, and JSON contracts.
- Use `$batch-grill-me` when product or engineering decisions are unresolved. Ask every currently unblocked decision-rich question in numbered rounds, with a recommended answer for each.
- Use `$domain-modeling` when terminology or business invariants need sharpening.
- Use `$tech-spec` when the work crosses important module boundaries or needs a typed call-stack handoff.
- Use the repository's documented standards. Use `$coding-standards` for TypeScript repositories.

Do not delegate the authority decisions or the final Task breakdown. Supporting agents may explore independent code areas only when explicitly allowed by the active instructions.

## Authority boundary

Requirement inspection, codebase exploration, and drafting are read-only. Run them when the source identifier and repository are clear.

Creating Tasks, adding comments, setting fields or readiness markers, and adding parent or dependency relations are mutating:

- Treat “plan,” “triage,” or “break down” as draft-only unless the user also says create, publish, or update tickets.
- Treat an explicit request to create/publish the resulting Tasks as authorization after the user approves the displayed breakdown.
- If the initial request explicitly authorizes publication, still show the final breakdown and obtain approval when material product choices or dependency edges required judgment.
- Never change, close, or delete the parent requirement; alter sprint assignment; or perform bulk cleanup unless explicitly requested.

## Workflow

### 1. Resolve the tracker contract

Read `docs/agents/issue-tracker.md`. Resolve the organization, project, team, repository, work-item type mapping, readiness mapping, relation names, and mutation policy. If the contract is absent or incomplete, discover safe scope with `$azure-devops-cli`; ask only for values that cannot be discovered.

Do not invent custom fields, tags, states, or relation names.

### 2. Build the source record

Fetch a complete `requirement.snapshot` for the Feature or User Story:

- current fields and relations;
- every scoped comment page;
- revisions and update deltas;
- attachment metadata;
- selected attachment contents only when needed and safe.

Record snapshot completeness and consistency. Stop before planning when essential history is incomplete or concurrent changes make the accepted baseline uncertain.

### 3. Verify and explore

Confirm the request is not already implemented, contradicted by current behavior, or rejected by an ADR or `.out-of-scope` record. Inspect the relevant runtime paths, public interfaces, tests, domain glossary, architecture decisions, and repository standards.

Separate findings into:

- established facts backed by ADO or repository evidence;
- inferred constraints with cited evidence;
- unresolved decisions requiring the user;
- implementation choices that the delivery agent may decide locally.

Do not turn ordinary implementation choices into product questions.

### 4. Clarify and batch grill

Resolve material ambiguity before publication. Use `$batch-grill-me` to map unresolved decisions as a dependency-aware design tree and ask the full currently unblocked frontier in each numbered round. Cover behavior, actors, boundaries, failure modes, compatibility, data migration, observability, security, rollout, accessibility when relevant, and explicit non-goals.

Update the proposed requirement interpretation after each round and recompute the decision frontier. Continue until the frontier is empty and the user confirms shared understanding. If answers change the parent requirement, propose the exact ADO update separately; do not silently rewrite it.

### 5. Design the Task graph

Create tracer-bullet vertical slices that produce independently demonstrable or verifiable behavior. Keep each Task small enough for one fresh context window.

Add preparatory Tasks only when they create a real enabling seam. For wide mechanical refactors, use expand–migrate–contract rather than pretending each layer is a vertical slice.

For every Task define:

- user-visible or operational outcome;
- acceptance criteria and non-goals;
- agreed public test seams and required evidence;
- relevant constraints and durable references;
- predecessor Tasks that genuinely block it;
- validation commands or discoverable validation expectations;
- readiness according to the tracker contract.

Keep the graph acyclic. Show a topological order and the initial execution frontier. Avoid file paths and speculative implementation details unless they encode an architectural decision that would otherwise be lost.

### 6. Approve and publish

Present the numbered Task graph with titles, outcomes, acceptance criteria, test seams, and blocking edges. Resolve requested merges, splits, or edge changes.

When authorized, publish Tasks in topological order so relations can reference real IDs:

1. Create each Task using the contract template.
2. Add the parent relation to the source requirement.
3. Add native predecessor/successor relations using the organization's verified relation names.
4. Apply the configured readiness state, field, or tag.
5. Read back every Task and relation; do not retry a partially successful mutation blindly.

If native dependency relations are unavailable, record stable work-item links in each Task's `Blocked by` section and report the fallback.

### 7. Produce the delivery handoff

Return the normalized handoff from the task contract, including parent revision, Task IDs and URLs, dependency edges, execution frontier, unresolved risks, and publication verification. This output is a summary; the ADO Task graph remains the durable handoff.

## Exit criteria

Finish only when:

- the accepted requirement snapshot is identified and its completeness is reported;
- no material product decision is hidden inside a Task;
- every Task satisfies the readiness checklist;
- every dependency edge is directional, verified, and acyclic;
- published Tasks match the approved draft; and
- a fresh agent can start from a Task ID without relying on chat history.

Do not implement code or create a PR in this skill.

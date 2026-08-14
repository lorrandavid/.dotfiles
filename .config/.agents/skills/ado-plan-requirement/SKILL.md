---
name: ado-plan-requirement
description: Turn an Azure DevOps requirement or existing deliverable into an approved, agent-ready plan. Use for Features and User Stories that need a dependency-ordered graph of child deliverables, or for Tasks, Bugs, and tracker-defined delivery work items that need an implementation plan recorded in place before delivery. Gather complete history, inspect the codebase, resolve ambiguities, define acceptance criteria and test seams, produce a hierarchical decomposition, and optionally publish and verify the approved plan in Azure DevOps.
---

# Plan an ADO Work Item

Produce the durable planning half of delivery. Treat the selected Azure DevOps work item and its history as the source record. For a requirement, publish an approved graph of child deliverables. For an existing deliverable, publish the approved implementation plan on that same work item. Make either result sufficient for a fresh agent to implement without this conversation.

Read [references/task-contract.md](references/task-contract.md) before drafting or publishing any plan or child work item.

## Compose the supporting skills

- Use `$azure-devops-cli` for every Azure DevOps read or mutation and follow its classifications, pagination, URL, and JSON contracts.
- Use `$grilling` when product or engineering decisions are unresolved. Ask every currently unblocked decision-rich question in numbered rounds, with a recommended answer for each.
- Use `$domain-modeling` when terminology or business invariants need sharpening.
- Use `$tech-spec` when the work crosses important module boundaries or needs a typed call-stack handoff.
- Use the repository's documented standards. Use `$coding-standards` for TypeScript repositories.

Do not delegate the authority decisions or the final Task breakdown. Supporting agents may explore independent code areas only when explicitly allowed by the active instructions.

## Authority boundary

Work-item inspection, codebase exploration, and drafting are read-only. Run them when the source identifier and repository are clear.

Creating child work items, publishing an approved-plan comment, setting fields or readiness markers, transitioning the source work item into a verified non-terminal state, and adding parent or dependency relations are mutating:

- Treat “plan,” “triage,” or “break down” as draft-only unless the user also says create, publish, or update tickets.
- Treat an explicit request to create, publish, or update the resulting plan as authorization after the user approves the displayed plan, including its approved-plan comment and an accurate non-terminal source-work-item transition or readiness marker.
- If the initial request explicitly authorizes publication, still show the final breakdown and obtain approval when material product choices or dependency edges required judgment.
- Draft-only planning never authorizes a state mutation. Report the recommended source state without applying it.
- Never close, complete, remove, or otherwise terminally transition the source work item; alter sprint assignment; or perform bulk cleanup unless explicitly requested.

## Workflow

### 1. Resolve the tracker contract

Read `docs/agents/issue-tracker.md`. Resolve the organization, project, team, repository, work-item type mapping, readiness mapping, lifecycle-state mapping, relation names, and mutation policy. Determine whether the selected type is a **requirement** that owns child delivery work or a **deliverable** that can be implemented directly. Use tracker configuration and hierarchy rather than hard-coded names: Feature and User Story commonly act as requirements; Task and Bug commonly act as deliverables, but customized processes may differ. If the contract is absent or incomplete, discover safe scope with `$azure-devops-cli`; ask only for values that cannot be discovered.

Fetch the configured state catalog for the source work item's exact type and for every child type that may be published. Preserve names, categories, and customization metadata. Do not invent custom fields, tags, states, type roles, or relation names.

### 2. Build the source record

Fetch a complete `requirement.snapshot` for the selected work item, regardless of type:

- current fields and relations;
- every scoped comment page;
- revisions and update deltas;
- attachment metadata;
- selected attachment contents only when needed and safe.

Record snapshot completeness and consistency. Capture its exact type, revision, parent, children, dependency relations, and any prior approved-plan comments. Stop before planning when essential history is incomplete or concurrent changes make the accepted baseline uncertain.

### 3. Verify and explore

Confirm the request is not already implemented, contradicted by current behavior, or rejected by an ADR or `.out-of-scope` record. Inspect the relevant runtime paths, public interfaces, tests, domain glossary, architecture decisions, and repository standards.

Separate findings into:

- established facts backed by ADO or repository evidence;
- inferred constraints with cited evidence;
- unresolved decisions requiring the user;
- implementation choices that the delivery agent may decide locally.

Do not turn ordinary implementation choices into product questions.

### 4. Clarify and batch grill

Resolve material ambiguity before publication. Use `$grilling` to map unresolved decisions as a dependency-aware design tree and ask the full currently unblocked frontier in each numbered round. Cover behavior, actors, boundaries, failure modes, compatibility, data migration, observability, security, rollout, accessibility when relevant, and explicit non-goals.

Update the proposed work-item interpretation after each round and recompute the decision frontier. Continue until the frontier is empty and the user confirms shared understanding. If answers change the source work item's requirements, propose the exact ADO update separately; do not silently rewrite it.

### 5. Design the plan

Always show a `Hierarchical Decomposition` based on confirmed architecture. Use a frontend composition tree, backend call tree, or frontend-to-API integration tree as appropriate. Show current and proposed trees when the distinction matters. Do not invent private helpers, classes, or file placement; mark unresolved structural choices as open questions.

Then follow the branch selected from the tracker contract.

#### Requirement: design the delivery graph

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

#### Deliverable: design the in-place implementation plan

Keep the selected Task, Bug, or other deliverable as the implementation unit. Apply the same planning rigor used for a newly created child work item: define its outcome, observable acceptance criteria, non-goals, public test seams, constraints, validation expectations, dependencies, risks, and relevant hierarchical-decomposition path.

Do not create child work beneath a deliverable by default. If it cannot fit one fresh implementation context or contains multiple independently deliverable outcomes, propose a split before publication. Prefer sibling deliverables under its existing requirement parent when the tracker hierarchy permits them. For a deliverable type that the tracker explicitly allows to own child delivery work, present that alternative for approval rather than assuming it.

Reconcile existing information instead of discarding it. Identify which current fields, criteria, relations, and comments remain valid, which proposed changes require approval, and whether an earlier approved plan is superseded. Never create a duplicate work item merely because the selected deliverable was not produced by this skill.

### 6. Approve and publish

Present the complete proposed plan for approval. For a requirement, include the numbered delivery graph with titles, outcomes, acceptance criteria, test seams, and blocking edges. For a deliverable, include the in-place implementation plan and any proposed split. Resolve requested merges, splits, edge changes, and architecture changes before publication.

When authorized, first synchronize the source work item to the tracker-configured planning or ready state appropriate to its role. Prefer the tracker contract's mapping; otherwise select an unambiguous non-terminal state using `$azure-devops-cli`'s lifecycle protocol. Do not move an existing deliverable to work-started merely because its plan was approved. If no unambiguous state exists, show the candidates and stop before publishing rather than guessing. Read back any transition.

Publish the approved-plan comment from the contract on the selected source work item. Include the accepted source revision, hierarchical decomposition, decisions, outcome, criteria, test seams, constraints and non-goals, validation, dependencies, risks, and either the child delivery graph or the explicit statement that the selected work item remains the delivery unit. If a prior approved plan exists, publish a new comment that identifies the superseded plan; do not silently edit history. Read the comment back and capture its ID or stable URL.

For a deliverable that remains the implementation unit, update only the explicitly approved fields or readiness marker, read back the work item and comment, then continue to the handoff. Do not create a replacement or child work item.

For a requirement, publish child work items in topological order so relations can reference real IDs:

1. Create each child deliverable using the contract template and reference the approved-plan comment.
2. Add the parent relation to the source requirement.
3. Add native predecessor/successor relations using the organization's verified relation names.
4. Apply the configured readiness state, field, or tag. When readiness uses `System.State`, select only from that child type's discovered catalog; prefer an explicit tracker mapping, then an unambiguous ready/not-started state. Never copy the source requirement's state name onto a child merely because it exists there.
5. Read back every child, approved-plan reference, state/readiness marker, and relation; do not retry a partially successful mutation blindly.

Do not move the source requirement to a completed state after task publication; planning completion is not requirement delivery completion.

If native dependency relations are unavailable, record stable work-item links in each Task's `Blocked by` section and report the fallback.

### 7. Produce the delivery handoff

Return the normalized handoff from the contract. Include planning mode, source revision, approved-plan comment identity, deliverable IDs and URLs, dependency edges, execution frontier, unresolved risks, publication verification, and lifecycle evidence. For in-place planning, identify the selected work item as the sole delivery unit. Record available states, previous/selected/final state, rationale, and readback verification. This output is a summary; the approved-plan comment plus the work item or delivery graph is the durable handoff.

## Exit criteria

Finish only when:

- the accepted work-item snapshot and planning mode are identified and completeness is reported;
- the approved plan contains a hierarchical decomposition grounded in confirmed architecture;
- no material product or engineering decision is hidden inside a deliverable;
- every planned deliverable satisfies the readiness checklist;
- every dependency edge is directional, verified, and acyclic;
- the approved-plan comment is read back and referenced by every published or updated deliverable;
- published or updated deliverables match the approved draft and their discovered readiness state;
- every authorized lifecycle transition was selected from the exact work-item type's configured states and read back; and
- a fresh agent can start from the selected deliverable ID without relying on chat history.

Do not implement code or create a PR in this skill.

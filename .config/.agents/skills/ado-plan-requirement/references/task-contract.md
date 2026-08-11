# Agent-ready Azure DevOps planning contract

Use this contract for every approved plan and every deliverable created or updated by the planner.

## Approved-plan comment

Publish this comment on the selected source work item after the user approves the plan and authorizes publication. For requirement planning, it is the canonical overview of the child delivery graph. For in-place planning, it is the canonical implementation plan for that deliverable.

````markdown
## Approved implementation plan

**Planning mode:** requirement decomposition / in-place deliverable
**Accepted source revision:** <revision>
**Supersedes:** <prior approved-plan comment, or "None">

### Outcome

<Observable user-visible or operational outcome.>

### Hierarchical decomposition

```text
<Frontend composition tree, backend call tree, or frontend-to-API integration tree.>
```

### Acceptance criteria

- [ ] <Observable behavior through a public interface>

### Test seams

- <Agreed public seam and behavior to prove>

### Constraints and non-goals

- <Durable architectural, domain, security, or scope constraint>

### Dependencies

- <Predecessor work item, external dependency, or "None">

### Validation

- <Repository command or evidence category>

### Delivery graph

- <Child deliverables and blocking edges, or "This work item remains the delivery unit">

### Risks and open questions

- <Resolved risk, residual risk, or "None">
````

Do not publish with unresolved material decisions. A later approved plan must name the comment it supersedes; preserve prior comments as planning history.

## Child-deliverable body

```markdown
## Parent requirement

ADO work item <parent-id>: <parent-title>
Accepted source revision: <revision>
Approved plan: <comment-id-or-url>

## Outcome

<One independently demonstrable user-visible or operational outcome.>

## Acceptance criteria

- [ ] <Observable behavior through a public interface>
- [ ] <Failure or boundary behavior when material>
- [ ] <Required compatibility, telemetry, migration, or rollout evidence>

## Test seams

- <Agreed public seam and behavior to prove>

## Constraints and non-goals

- <Durable architectural, domain, security, or scope constraint>

## Blocked by

- <ADO Task ID and title, or “None — can start immediately”>

## Validation

- <Repository command or evidence category; discover exact command when repository-owned>
```

For an existing deliverable planned in place, retain its identity and reconcile these same sections into its approved-plan comment and explicitly approved fields rather than creating another work item. Keep acceptance criteria behavior-oriented. Do not prescribe private classes, helper functions, or exact file placement unless an approved architecture decision requires it.

## Readiness checklist

A deliverable is agent-ready only when:

- its source work item, accepted source revision, and approved-plan comment are known;
- the outcome is one coherent vertical slice;
- acceptance criteria are observable and non-contradictory;
- test seams are explicit and agreed;
- dependencies reference real Tasks and form no cycle;
- relevant standards, ADRs, and domain terms are discoverable;
- material product decisions and external-access requirements are resolved;
- validation expectations are stated; and
- it fits one fresh implementation context.

## Normalized handoff

```json
{
  "operation": "requirement.task-graph.publish",
  "classification": "mutating",
  "planningMode": "requirement-decomposition",
  "approvedPlanComment": {
    "id": 128,
    "url": "<comment-url>",
    "verified": true
  },
  "source": {
    "id": 4102,
    "revision": 17,
    "url": "<portal-url>",
    "snapshotComplete": true,
    "lifecycle": {
      "moment": "planning-started",
      "previousState": "New",
      "selectedState": "Active",
      "finalState": "Active",
      "verified": true
    }
  },
  "tasks": [
    {
      "id": 4201,
      "title": "<title>",
      "url": "<portal-url>",
      "ready": true,
      "state": "To Do",
      "stateCategory": "Proposed",
      "stateVerified": true,
      "blockedBy": []
    }
  ],
  "edges": [
    { "predecessor": 4201, "successor": 4202, "verified": true }
  ],
  "frontier": [4201],
  "unresolvedRisks": [],
  "publicationVerified": true
}
```

For an unpublished draft, use `operation: work-item.plan.draft`, `classification: read-only`, and `publicationVerified: false`. For a published requirement graph, use `operation: requirement.task-graph.publish`; for a published in-place plan, use `operation: deliverable.plan.publish` and return the source work item as the sole delivery unit. Include `planningMode`, `approvedPlanComment`, and the recommended lifecycle selection. Preserve each exact work-item type's discovered state catalog alongside the normalized handoff when lifecycle evidence is needed; the example state names are illustrative, never defaults.

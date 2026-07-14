# Agent-ready Azure DevOps Task contract

Use this contract for every Task created from a Feature or User Story.

## Task body

```markdown
## Parent requirement

ADO work item <parent-id>: <parent-title>
Accepted source revision: <revision>

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

Keep acceptance criteria behavior-oriented. Do not prescribe private classes, helper functions, or exact file placement unless an approved architecture decision requires it.

## Readiness checklist

A Task is agent-ready only when:

- its parent and accepted parent revision are known;
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
  "source": {
    "id": 4102,
    "revision": 17,
    "url": "<portal-url>",
    "snapshotComplete": true
  },
  "tasks": [
    {
      "id": 4201,
      "title": "<title>",
      "url": "<portal-url>",
      "ready": true,
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

For an unpublished draft, use `operation: requirement.task-graph.draft`, `classification: read-only`, and `publicationVerified: false`. Use `requirement.task-graph.publish` only after a publication attempt.

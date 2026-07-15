# Task delivery and stacked draft PR contract

## Per-Task implementation evidence

```json
{
  "taskId": 4201,
  "sourceRevision": 6,
  "implementation": { "skill": "implement", "status": "completed" },
  "commits": ["<sha>"],
  "acceptanceCriteria": [
    { "criterion": "<observable behavior>", "status": "passed", "evidence": "<test or inspection>" }
  ],
  "validation": [
    { "command": "<command>", "status": "passed", "summary": "<concise result>" }
  ],
  "review": {
    "standards": [],
    "spec": [],
    "cdd": {
      "verdict": "pass-with-concerns",
      "readerTasks": [
        "Change the primary rule introduced by this Task",
        "Diagnose the most important failure mode"
      ],
      "metrics": { "source": "qualitative", "tool": null },
      "attempts": [
        {
          "round": 0,
          "verdict": "revise",
          "introducedHighFindings": 1
        },
        {
          "round": 1,
          "verdict": "pass-with-concerns",
          "introducedHighFindings": 0
        }
      ],
      "findings": [
        {
          "severity": "medium",
          "status": "unresolved-explained",
          "location": "<path:line or bounded cross-file path>",
          "summary": "<concise cognitive-load concern>"
        }
      ],
      "preExistingFindings": [],
      "remediationRounds": 1
    }
  },
  "unresolved": []
}
```

Use `blocked`, `failed`, or `not-run` rather than claiming success without evidence.

## Draft PR description

Use the Conventional Commit subject as the PR title: `<type>(#<task-id>): <brief description>`.

```markdown
## Requirement

- Parent: AB#<parent-id> — <title>
- Task: AB#<task-id> — <title>
- Stacked on: <predecessor PR and branch, or “base branch”>

## What changed

<Concise behavior-oriented summary for this Task only.>

## Acceptance evidence

| Acceptance criterion | Evidence |
| --- | --- |
| <criterion> | <test, command, or inspection> |

## How to review

1. <First behavior or module to inspect>
2. <Second behavior or integration point>

## Cognitive-load review

- Verdict: <Pass or Pass with concerns>
- Reader tasks: <maintenance tasks used by the CDD review>
- Metrics: <configured analyzer and scope, or “Qualitative; no configured analyzer”>
- Unresolved concerns: <explicit concerns or “None”>

## Validation

- `<command>` — passed

## Risk and rollout

- <Migration, compatibility, telemetry, deployment, or “No special rollout”.>

## Known limitations or skipped checks

- <Explicit item or “None”.>
```

Keep every PR limited to one Task. Do not hide failing or skipped checks. Keep the PR draft while known required work remains.

## Normalized delivery result

```json
{
  "operation": "task-selection.deliver",
  "classification": "mutating",
  "source": { "id": 4102, "acceptedRevision": 17, "observedRevision": 17 },
  "selection": {
    "mode": "all",
    "requested": "all",
    "resolvedTaskIds": [4201, 4202, 4203]
  },
  "scheduler": {
    "workspaceMode": "worktree",
    "maxConcurrency": 2,
    "states": {
      "pr-published": [4201, 4202],
      "blocked": [4203],
      "failed": []
    }
  },
  "tasks": [
    {
      "id": 4201,
      "status": "pr-published",
      "worktree": "<absolute-path>",
      "branch": "feat/4201-revoke-active-sessions",
      "baseBranch": "main",
      "stackedOn": null,
      "commitSubjects": ["feat(#4201): revoke active sessions"],
      "implementation": { "skill": "implement", "status": "completed" },
      "commits": ["<sha>"],
      "quality": {
        "tests": "passed",
        "typecheck": "passed",
        "standardsReviewFindings": 0,
        "specReviewFindings": 0,
        "cddVerdict": "pass-with-concerns",
        "cddHighFindings": 0,
        "cddUnresolvedFindings": 1,
        "cddRemediationRounds": 1,
        "deslopComplete": true
      },
      "pullRequest": {
        "id": 88,
        "url": "<portal-url>",
        "isDraft": true,
        "sourceBranch": "feat/4201-revoke-active-sessions",
        "targetBranch": "main",
        "linkedWorkItems": [4102, 4201],
        "mergeStatus": "succeeded"
      }
    },
    {
      "id": 4203,
      "status": "blocked",
      "blockedBy": [4202],
      "reason": "Predecessor PR is not published"
    }
  ],
  "unselectedTaskIds": [],
  "remaining": [4203]
}
```

For a stacked Task, set `baseBranch` and `pullRequest.targetBranch` to the predecessor's source branch and set `stackedOn` to its Task ID, PR ID, branch, and head commit. Keep raw ADO results when the observed schema cannot be normalized safely.

# Task delivery and stacked draft PR contract

## Per-Task implementation evidence

The `planning` object is optional. Include it only when the user supplied a plan or explicitly required one. Record the exact source and only the verification properties the user requested.

```json
{
  "taskId": 4201,
  "sourceRevision": 6,
  "planning": {
    "required": false,
    "source": {
      "kind": "file",
      "location": "docs/plans/revoke-sessions.md"
    },
    "used": true
  },
  "lifecycle": {
    "workItemType": "Task",
    "availableStates": [
      { "name": "To Do", "category": "Proposed" },
      { "name": "Doing", "category": "InProgress" },
      { "name": "Ready for Review", "category": "InProgress" },
      { "name": "Done", "category": "Completed" }
    ],
    "transitions": [
      {
        "moment": "work-started",
        "previousState": "To Do",
        "selectedState": "Doing",
        "finalState": "Doing",
        "selectionReason": "Configured InProgress state",
        "verified": true
      },
      {
        "moment": "pr-published",
        "previousState": "Doing",
        "selectedState": "Ready for Review",
        "finalState": "Ready for Review",
        "selectionReason": "Explicit configured review state",
        "verified": true
      }
    ]
  },
  "implementation": { "skill": "implement", "status": "completed" },
  "history": {
    "targetHead": "<sha>",
    "targetIsAncestor": true,
    "taskCommitCount": 1,
    "squashedCommit": "<sha>",
    "subject": "feat(#4201): revoke active sessions",
    "remoteVerified": true
  },
  "commits": ["<single-squashed-sha>"],
  "acceptanceCriteria": [
    { "criterion": "<observable behavior>", "status": "passed", "evidence": "<test or inspection>" }
  ],
  "validation": [
    { "command": "<command>", "status": "passed", "summary": "<concise result>" }
  ],
  "pipeline": {
    "definitionId": 17,
    "definitionName": "Repository CI",
    "branch": "refs/heads/feat/4201-revoke-active-sessions",
    "finalSourceVersion": "<sha>",
    "finalResult": "succeeded",
    "attempts": [
      {
        "runId": 901,
        "url": "<portal-url>",
        "sourceVersion": "<failing-sha>",
        "status": "completed",
        "result": "failed",
        "failures": ["<failed step and concise error>"]
      },
      {
        "runId": 902,
        "url": "<portal-url>",
        "sourceVersion": "<successful-sha>",
        "status": "completed",
        "result": "succeeded",
        "failures": []
      }
    ]
  },
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

Render the following template to a UTF-8 Markdown file with actual LF line breaks. Supply that file's contents as one quoted value when creating or updating the PR. Literal `\n` text, shell-escaped newline sequences, and whitespace-flattened descriptions violate this contract.

```markdown
## Requirement

- Parent: AB#<parent-id> — <title>
- Task: AB#<task-id> — <title>
- Plan: <source and requested verification, only when a plan was supplied or required>
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
- Azure Pipeline `<definition-name>` run [#<run-id>](<portal-url>) for `<source-sha>` — succeeded

## Risk and rollout

- <Migration, compatibility, telemetry, deployment, or “No special rollout”.>

## Known limitations or skipped checks

- <Explicit item or “None”.>
```

Omit the `Plan` bullet entirely when no plan was supplied or required. A plan may come from inline text, a file, URL, ADO comment or attachment, or a named ADO field; preserve enough provenance for a reviewer to locate the exact input.

Keep every PR limited to one Task. Before creating it, require the Task-owned range from the freshly fetched target head to the source head to contain exactly one squashed commit, require that target head to be an ancestor of the source, and require the successful pipeline source version and remote source head to equal that commit. For stacked PRs, predecessor commits are outside this range and must not be rewritten. Do not hide failing or skipped checks. Keep the PR draft while known required work remains. Read the PR back and verify that its description contains the section headings on separate lines and no literal `\n` sequences.

## Normalized delivery result

```json
{
  "operation": "task-selection.deliver",
  "classification": "mutating",
  "source": { "id": 4102, "observedRevision": 17 },
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
      "worktreeCleanup": {
        "result": "removed",
        "gitRegistered": false,
        "pathExists": false,
        "temporaryFilesRemoved": true,
        "pruned": true,
        "commandsVerified": true
      },
      "branch": "feat/4201-revoke-active-sessions",
      "baseBranch": "main",
      "stackedOn": null,
      "lifecycle": {
        "workItemType": "Task",
        "currentState": "Ready for Review",
        "currentStateCategory": "InProgress",
        "verified": true
      },
      "commitSubjects": ["feat(#4201): revoke active sessions"],
      "history": {
        "targetHead": "<sha>",
        "targetIsAncestor": true,
        "taskCommitCount": 1,
        "squashedCommit": "<sha>",
        "remoteVerified": true
      },
      "implementation": { "skill": "implement", "status": "completed" },
      "commits": ["<single-squashed-sha>"],
      "quality": {
        "tests": "passed",
        "typecheck": "passed",
        "pipeline": {
          "definitionId": 17,
          "definitionName": "Repository CI",
          "runId": 902,
          "url": "<portal-url>",
          "branch": "refs/heads/feat/4201-revoke-active-sessions",
          "sourceVersion": "<sha>",
          "result": "succeeded",
          "attemptCount": 2
        },
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

Keep `worktree` as the original absolute path for traceability. Populate `worktreeCleanup` only after the final cleanup sweep. Set `result` to `removed` only when the exact path is absent from both `git worktree list --porcelain` and the filesystem after pruning. Use `preserved-dirty` when local changes prevent safe removal, `removal-failed` when the clean worktree or directory could not be removed safely, or `preserved` when publication did not complete and recovery rules retain the worktree. Include the observed git-registration and filesystem-existence booleans plus any cleanup error. A published Task with any result other than `removed` makes the overall operation `delivered-with-cleanup-failures`, not fully complete.

The lifecycle state names in these examples are illustrative. Always record the exact catalog discovered for the Task's project and work-item type. A `pr-published` Task may legitimately remain in its configured in-progress state when no explicit review state exists; never substitute a completed state.

Preserve every pipeline attempt in the implementation evidence, including failed runs and their diagnostic summaries. The normalized `quality.pipeline` object identifies only the final successful run, whose `branch` and `sourceVersion` must match the PR source branch, its current remote head, and `history.squashedCommit`. Record the freshly fetched PR target head in `history.targetHead`; `history.taskCommitCount` must be `1` at creation time. Omit `pullRequest` entirely when the history gate or exact-SHA pipeline gate did not succeed.

# Azure DevOps command reference

Use these patterns after the core workflow in `SKILL.md`. Examples are single-line to avoid shell-specific continuation syntax. Replace every placeholder, quote substituted values for the active shell, and retain `--only-show-errors --output json` for data operations.

## Contents

- [Shared inspection](#shared-inspection)
- [Work items](#work-items)
- [Work-item state discovery and transitions](#work-item-state-discovery-and-transitions)
- [Requirement history and attachments](#requirement-history-and-attachments)
- [Work-item relations and PR links](#work-item-relations-and-pr-links)
- [Pipelines](#pipelines)
- [Pull requests](#pull-requests)
- [PR reviewers, votes, policies, and conflicts](#pr-reviewers-votes-policies-and-conflicts)
- [PR comments](#pr-comments)
- [Sprints and iterations](#sprints-and-iterations)
- [Structured output patterns](#structured-output-patterns)
- [Authoritative references](#authoritative-references)

## Shared inspection

Inspect defaults:

```text
az devops configure --list --output json
```

Resolve a repository name and ID before commands that require a repository ID:

```text
az repos show --repository <repo-name-or-id> --project <project> --org <org-url> --query '{id:id,name:name,projectId:project.id,projectName:project.name,webUrl:webUrl}' --only-show-errors --output json
```

When a PR ID is already available, run `az repos pr show --id <pr-id> --org <org-url>` first and derive `repository.id`, `repository.name`, `repository.project.id`, and `repository.project.name` from its response. Do not ask the user to repeat discoverable scope.

Prefer explicit `--org`, `--project`, and `--repository` in automation prompts even when defaults exist.

## Work items

### Read and query — read-only

Show a work item with relations:

```text
az boards work-item show --id <work-item-id> --expand relations --org <org-url> --only-show-errors --output json
```

Query work items with WIQL:

```text
az boards query --org <org-url> --project <project> --wiql "SELECT [System.Id], [System.Title], [System.State], [System.AssignedTo], [System.IterationPath] FROM WorkItems WHERE [System.TeamProject] = @project AND [System.State] <> 'Closed' ORDER BY [System.ChangedDate] DESC" --only-show-errors --output json
```

Use `@Me` for the authenticated identity and `@CurrentIteration` only when the team context is unambiguous.

### Create — mutating

Create a work item:

```text
az boards work-item create --org <org-url> --project <project> --type <work-item-type> --title <title> --description <description> --assigned-to <identity> --area <area-path> --iteration <iteration-path> --fields <field-reference-name>=<value> --only-show-errors --output json
```

Pass only requested optional fields. Process-specific field reference names vary; inspect an existing item or process metadata rather than guessing.

### Update — mutating

Read the current item, then update only requested fields:

```text
az boards work-item update --id <work-item-id> --org <org-url> --title <title> --state <state> --assigned-to <identity> --iteration <iteration-path> --fields <field-reference-name>=<value> --only-show-errors --output json
```

Add a discussion comment:

```text
az boards work-item update --id <work-item-id> --org <org-url> --discussion <comment> --only-show-errors --output json
```

Classify discussion updates as `work-item.comment`. Read the item back after creation or update.

## Work-item state discovery and transitions

Read the item first and retain its project, `System.WorkItemType`, `System.State`, and `rev`:

```text
az boards work-item show --id <work-item-id> --expand fields --org <org-url> --query '{id:id,project:fields."System.TeamProject",type:fields."System.WorkItemType",state:fields."System.State",revision:rev}' --only-show-errors --output json
```

List the states configured for that exact project and work-item type:

```text
az devops invoke --area wit --resource workItemTypeStates --route-parameters project=<project> type=<work-item-type> --org <org-url> --api-version 7.1-preview.1 --http-method GET --only-show-errors --output json
```

Preserve the raw response and normalize at least `name`, `category`, `order`, and `customizationType` when present. The route value for a type containing spaces must be passed as one native argument and URL-encoded by the active client; do not manually concatenate a REST URL. If the resource name cannot be resolved, discover the current WIT resources read-only with `az devops invoke --query "[?area=='wit']" --only-show-errors --output json` and select the route whose template ends in `workitemtypes/{type}/states`.

Choose a state using the lifecycle protocol in `SKILL.md`. Do not infer availability from another item or type in the same project. Transition only to the selected configured state:

```text
az boards work-item update --id <work-item-id> --org <org-url> --state <configured-state-name> --only-show-errors --output json
```

Then read the item back and verify the exact state and revision. Normalize the operation as:

```json
{
  "operation": "work-item.state.transition",
  "classification": "mutating",
  "id": 4201,
  "type": "Task",
  "moment": "work-started",
  "previousState": "To Do",
  "availableStates": [
    { "name": "To Do", "category": "Proposed" },
    { "name": "Doing", "category": "InProgress" },
    { "name": "Done", "category": "Completed" }
  ],
  "selectedState": "Doing",
  "selectionReason": "The configured InProgress state for this Task type",
  "finalState": "Doing",
  "verified": true
}
```

If no unambiguous state fits, use `selectedState: null`, leave the item unchanged, and return the candidates and reason. Do not test transitions by making speculative updates.

## Requirement history and attachments

Use these read-only operations to build the complete source record before clarifying, decomposing, or implementing a requirement. Fetch the current item first and record its `rev`:

```text
az boards work-item show --id <work-item-id> --expand all --org <org-url> --only-show-errors --output json
```

### Discussion comments — continuation-token pagination

List the first page in chronological order:

```text
az devops invoke --area wit --resource comments --route-parameters project=<project> workItemId=<work-item-id> --query-parameters '$top=<page-size>' 'order=asc' --org <org-url> --api-version 7.1-preview.4 --http-method GET --only-show-errors --output json
```

If the response contains a non-empty `continuationToken`, request the next page and repeat until it is absent:

```text
az devops invoke --area wit --resource comments --route-parameters project=<project> workItemId=<work-item-id> --query-parameters '$top=<page-size>' 'continuationToken=<token>' 'order=asc' --org <org-url> --api-version 7.1-preview.4 --http-method GET --only-show-errors --output json
```

Preserve comment IDs, versions, authors, created/modified dates, deletion state, and text. Use `includeDeleted=true` when the user requests “all comments,” audit history, or deleted comments can materially affect interpretation. Record `includeDeleted` in normalized pagination metadata so “complete” has an explicit scope. Do not substitute the `System.History` field for this collection.

### Fully hydrated revisions — offset pagination

```text
az devops invoke --area wit --resource revisions --route-parameters project=<project> id=<work-item-id> --query-parameters '$top=<page-size>' '$skip=<offset>' '$expand=all' --org <org-url> --api-version 7.1 --http-method GET --only-show-errors --output json
```

Start at offset `0`, increase `$skip` by the number returned, and continue until the server returns an empty page or a trustworthy server-provided total proves the collection is exhausted. Do not assume a short page is terminal because the service may cap page size below the requested `$top`. Preserve `rev`, fields, relations when expanded, and `commentVersionRef`. Revisions are complete snapshots and may be large; normalize only the fields relevant to requirement interpretation while retaining raw JSON when provenance matters.

### Update deltas — offset pagination

```text
az devops invoke --area wit --resource updates --route-parameters project=<project> id=<work-item-id> --query-parameters '$top=<page-size>' '$skip=<offset>' --org <org-url> --api-version 7.1 --http-method GET --only-show-errors --output json
```

Page as for revisions. Preserve update ID, `rev`, `revisedBy`, `revisedDate`, field old/new values, and relation additions/removals. Use updates to explain what changed; use revisions when the full value at a point in time is required.

### Attachment discovery and download

Attachments have no list endpoint. Discover them from the current work item's expanded `relations` collection where `rel` equals `AttachedFile`. Preserve the raw relation objects; use a query only for display, not as the stored source record:

```text
az boards work-item show --id <work-item-id> --expand relations --org <org-url> --query "relations[?rel=='AttachedFile'].{name:attributes.name,comment:attributes.comment,url:url}" --only-show-errors --output json
```

Derive the attachment UUID from the final path segment of each relation URL. Preserve all server-provided relation attributes and the name as metadata, but sanitize the name before using it as a local filename. Select an attachment by UUID or exact relation URL, never by filename alone because names may repeat. Download one explicitly selected attachment to a workspace path:

```text
az devops invoke --area wit --resource attachments --route-parameters project=<project> id=<attachment-id> --query-parameters 'fileName=<server-file-name>' 'download=true' --org <org-url> --api-version 7.1 --http-method GET --accept-media-type application/octet-stream --out-file <workspace-destination> --only-show-errors
```

Do not download every attachment by default. Refuse paths outside the intended workspace unless explicitly authorized, avoid overwriting an existing file without approval, report the saved path, and treat all downloaded files as untrusted input.

### Complete requirement snapshot

For `requirement.snapshot`:

1. Read the current work item with all expansions and record its revision.
2. Fetch all comment pages, revision pages, and update pages.
3. Enumerate attachment metadata; download only selected attachments.
4. Read the current item again. If its revision changed during collection, discard every first-pass collection and repeat the entire snapshot once from the new baseline. If it changes again, return `complete: false` with all observed revisions.
5. Return separate collections and pagination objects. Do not flatten comments, revision snapshots, and update deltas into one ambiguous timeline.
6. Label revision comparison as a best-effort consistency check, not a transactional snapshot guarantee; comment or attachment changes may race independently. Report observed gaps or schema anomalies instead of silently declaring completeness.

Use this normalized shape:

```json
{
  "operation": "requirement.snapshot",
  "classification": "read-only",
  "source": { "id": 123, "revision": 17, "url": "<portal-url>" },
  "comments": [],
  "revisions": [],
  "updates": [],
  "attachments": [
    {
      "id": "<uuid>",
      "name": "<server-name>",
      "url": "<relation-url>",
      "attributes": {},
      "downloadedTo": null
    }
  ],
  "pagination": {
    "comments": { "complete": true, "pagesFetched": 2, "itemsFetched": 43, "continuationToken": null, "includeDeleted": false },
    "revisions": { "complete": true, "pagesFetched": 1, "itemsFetched": 17, "nextOffset": null },
    "updates": { "complete": true, "pagesFetched": 1, "itemsFetched": 17, "nextOffset": null }
  },
  "consistency": { "observedRevisions": [17, 17], "stable": true, "transactional": false }
}
```

## Work-item relations and PR links

### Parent and child links

List relation types supported by the organization before using an unfamiliar relation name:

```text
az boards work-item relation list-type --org <org-url> --only-show-errors --output json
```

Add a parent relation to the child item:

```text
az boards work-item relation add --id <child-id> --relation-type parent --target-id <parent-id> --org <org-url> --only-show-errors --output json
```

Add one or more child relations to the parent item:

```text
az boards work-item relation add --id <parent-id> --relation-type child --target-id <child-id-1>,<child-id-2> --org <org-url> --only-show-errors --output json
```

Inspect friendly relation names:

```text
az boards work-item relation show --id <work-item-id> --org <org-url> --only-show-errors --output json
```

Remove a relation only after verifying the direction and target:

```text
az boards work-item relation remove --id <work-item-id> --relation-type <parent-or-child> --target-id <target-work-item-id> --org <org-url> --yes --only-show-errors --output json
```

### Related PR links

Use the dedicated PR work-item commands instead of constructing artifact URIs:

```text
az repos pr work-item list --id <pr-id> --org <org-url> --only-show-errors --output json
az repos pr work-item add --id <pr-id> --work-items <work-item-id-1> <work-item-id-2> --org <org-url> --only-show-errors --output json
az repos pr work-item remove --id <pr-id> --work-items <work-item-id-1> <work-item-id-2> --org <org-url> --only-show-errors --output json
```

Read both the PR and work item first when project or repository scope is uncertain, then verify the linked-work-item list.

## Pipelines

### Resolve a repository pipeline — read-only

Prefer the pipeline ID recorded by repository instructions. Otherwise list pipelines associated with the Azure Repos repository:

```text
az pipelines list --repository <repo-name-or-id> --repository-type tfsgit --project <project> --org <org-url> --only-show-errors --output json
```

Show the selected definition and verify its ID, name, repository, YAML path, default branch, queue status, and required parameters:

```text
az pipelines show --id <pipeline-id> --project <project> --org <org-url> --only-show-errors --output json
```

Do not choose by name similarity when multiple applicable definitions remain. Return the candidates and require the caller to resolve the pipeline contract.

### Queue an exact branch revision — mutating

Push the branch first and verify the expected commit is its remote head. Queue the selected pipeline against both that branch and commit:

```text
az pipelines run --id <pipeline-id> --branch refs/heads/<source-branch> --commit-id <source-sha> --project <project> --org <org-url> --only-show-errors --output json
```

Pass only repository-defined `--parameters` or `--variables`; never guess secret or environment values. Preserve the complete response and returned run ID. Queueing is non-idempotent: if the response is lost or ambiguous, list recent runs for the pipeline and branch, then compare their `definition.id`, `sourceBranch`, and `sourceVersion` before deciding whether a retry is needed:

```text
az pipelines runs list --pipeline-ids <pipeline-id> --branch refs/heads/<source-branch> --query-order QueueTimeDesc --top <small-limit> --project <project> --org <org-url> --only-show-errors --output json
```

### Monitor and diagnose a run — read-only

Poll the captured run ID at a reasonable interval until `status` is `completed`:

```text
az pipelines runs show --id <run-id> --project <project> --org <org-url> --only-show-errors --output json
```

Do not infer success from command exit status or a completed state alone. Require `result` to equal `succeeded`; treat `partiallySucceeded`, `failed`, and `canceled` as non-passing. Verify `definition.id`, `sourceBranch`, and `sourceVersion` against the requested pipeline, branch, and commit.

For a non-passing run, fetch its timeline and use failed records, issues, and `log.id` values to select relevant diagnostics:

```text
az devops invoke --area build --resource timeline --route-parameters project=<project> buildId=<run-id> --org <org-url> --api-version 7.1 --http-method GET --only-show-errors --output json
```

Fetch only logs relevant to failed records. List log metadata when the timeline does not identify a usable log:

```text
az devops invoke --area build --resource logs --route-parameters project=<project> buildId=<run-id> --org <org-url> --api-version 7.1 --http-method GET --only-show-errors --output json
```

Read a selected log as text:

```text
az devops invoke --area build --resource logs --route-parameters project=<project> buildId=<run-id> logId=<log-id> --org <org-url> --api-version 7.1-preview.2 --http-method GET --accept-media-type text/plain --only-show-errors
```

Preserve the run ID, definition, branch, source version, status, result, portal URL, failed timeline records, issues, and concise relevant log excerpts. Never expose secret variables or authorization material from logs.

## Pull requests

### Read — read-only

List active PRs:

```text
az repos pr list --repository <repo-name-or-id> --project <project> --org <org-url> --status active --include-links --only-show-errors --output json
```

Show a PR with merge and conflict fields:

```text
az repos pr show --id <pr-id> --org <org-url> --query '{id:pullRequestId,title:title,status:status,isDraft:isDraft,mergeStatus:mergeStatus,mergeFailureType:mergeFailureType,mergeFailureMessage:mergeFailureMessage,source:sourceRefName,target:targetRefName,repositoryId:repository.id,repository:repository.name,projectId:repository.project.id,project:repository.project.name,createdBy:createdBy.displayName,creationDate:creationDate}' --only-show-errors --output json
```

### Create — mutating

Create a PR and link work items in the same operation when possible. For a multiline description, first render the final Markdown to a temporary UTF-8 file, inspect it, and pass its contents as one quoted argument. In Bash:

```text
az repos pr create --repository <repo-name-or-id> --project <project> --org <org-url> --source-branch <source-branch> --target-branch <target-branch> --title <title> --description "$(<description.md)" --work-items <work-item-id-1> <work-item-id-2> --optional-reviewers <identity> --required-reviewers <identity> --only-show-errors --output json
```

Do not put literal `\n` sequences in `--description`, omit the quotes around command substitution, or collapse the Markdown to one line. When the active shell is not Bash, use that shell's equivalent file-to-single-argument mechanism and verify that it preserves real line breaks. Do not enable auto-complete, policy bypass, source-branch deletion, or work-item transitions unless explicitly requested.

### Update — mutating or high-impact

Update metadata or draft state. Preserve multiline Markdown with the same file-based approach used for creation:

```text
az repos pr update --id <pr-id> --org <org-url> --title <title> --description "$(<description.md)" --draft <true-or-false> --only-show-errors --output json
```

After creating or updating a PR, read its unfiltered `description` back from the server. Compare it with the rendered Markdown and verify that headings remain on separate lines and that the value contains no literal `\n` sequences. If formatting differs, correct the invocation and read it back again before reporting success.

Treat `--status completed`, `--status abandoned`, `--bypass-policy true`, `--delete-source-branch true`, and `--transition-work-items true` as high-impact. Read policies and merge status immediately before completing a PR, and read the PR back afterward.

## PR reviewers, votes, policies, and conflicts

### Reviewers

```text
az repos pr reviewer list --id <pr-id> --org <org-url> --only-show-errors --output json
az repos pr reviewer add --id <pr-id> --reviewers <identity-1> <identity-2> --required <true-or-false> --org <org-url> --only-show-errors --output json
az repos pr reviewer remove --id <pr-id> --reviewers <identity-1> <identity-2> --org <org-url> --only-show-errors --output json
```

Resolve ambiguous display names before mutation. Prefer unique names, email-style identities, or descriptors accepted by the command.

### Votes

```text
az repos pr set-vote --id <pr-id> --vote <approve|approve-with-suggestions|reject|reset|wait-for-author> --org <org-url> --only-show-errors --output json
```

Voting is mutating collaboration state. Never infer a vote from a code review; require the user to request the specific vote.

### Policies

List PR policy evaluations:

```text
az repos pr policy list --id <pr-id> --org <org-url> --only-show-errors --output json
```

Queue a specific evaluation only when requested:

```text
az repos pr policy queue --id <pr-id> --evaluation-id <evaluation-id> --org <org-url> --only-show-errors --output json
```

Use `az repos policy list` for branch-policy configuration; do not confuse configuration with the PR-specific evaluation result.

### Conflict status

Read `mergeStatus`, `mergeFailureType`, and `mergeFailureMessage` from `az repos pr show`:

- `conflicts`: the server detected merge conflicts.
- `rejectedByPolicy`: policy rejected the merge; this is not a file conflict.
- `failure`: merge processing failed; report the failure fields.
- `queued` or `notSet`: status is not final; do not claim the PR is conflict-free.
- `succeeded`: the server-side merge calculation succeeded, subject to current policy state.

Do not determine ADO conflict status solely from a local `git merge` trial.

## PR comments

The Azure DevOps CLI extension has no first-class PR comment command. Use `az devops invoke` against Git pull-request thread resources.

Resolve the PR's target `repository.id`, then list comment threads — read-only:

```text
az devops invoke --area git --resource pullRequestThreads --route-parameters project=<project> repositoryId=<repository-id> pullRequestId=<pr-id> --org <org-url> --api-version 7.1 --http-method GET --only-show-errors --output json
```

To create a top-level PR comment, write this request body to a temporary JSON file:

```json
{
  "comments": [
    {
      "parentCommentId": 0,
      "content": "<comment>",
      "commentType": 1
    }
  ],
  "status": 1
}
```

Then run the mutating request:

```text
az devops invoke --area git --resource pullRequestThreads --route-parameters project=<project> repositoryId=<repository-id> pullRequestId=<pr-id> --org <org-url> --api-version 7.1 --http-method POST --in-file <request.json> --only-show-errors --output json
```

Use the `pullRequestThreadComments` REST resource to reply to a known thread, supplying `threadId` and a body containing `content`, `parentCommentId`, and `commentType`. For line comments, obtain iteration and change-tracking context first; never guess line positions or iteration IDs.

If resource resolution fails, discover the current route names read-only:

```text
az devops invoke --query "[?area=='git']" --only-show-errors --output json
```

## Sprints and iterations

### Project iterations — read-only

List the project iteration tree:

```text
az boards iteration project list --project <project> --org <org-url> --depth <depth> --only-show-errors --output json
```

Show an iteration by identifier:

```text
az boards iteration project show --id <iteration-id> --project <project> --org <org-url> --only-show-errors --output json
```

### Team sprint queries — read-only

List the current team iteration:

```text
az boards iteration team list --team <team-name-or-id> --project <project> --org <org-url> --timeframe Current --only-show-errors --output json
```

List work items in an iteration:

```text
az boards iteration team list-work-items --id <iteration-id> --team <team-name-or-id> --project <project> --org <org-url> --only-show-errors --output json
```

Show configured backlog and default iterations:

```text
az boards iteration team show-backlog-iteration --team <team-name-or-id> --project <project> --org <org-url> --only-show-errors --output json
az boards iteration team show-default-iteration --team <team-name-or-id> --project <project> --org <org-url> --only-show-errors --output json
```

Team iteration add/remove and default/backlog setters are mutating. Project iteration create/update/delete is outside a query request and requires explicit scope; deletion is high-impact.

## Structured output patterns

Use JMESPath to normalize server output before wrapping it in the core output envelope.

Work item:

```text
--query '{id:id,title:fields."System.Title",state:fields."System.State",assignedTo:fields."System.AssignedTo".displayName,iterationPath:fields."System.IterationPath",revision:rev}'
```

PR summary:

```text
--query '{id:pullRequestId,title:title,status:status,isDraft:isDraft,mergeStatus:mergeStatus,source:sourceRefName,target:targetRefName,repository:repository.name,project:repository.project.name}'
```

PR list:

```text
--query '[].{id:pullRequestId,title:title,status:status,isDraft:isDraft,creator:createdBy.displayName,source:sourceRefName,target:targetRefName,repository:repository.name}'
```

Do not rely on display-formatted `table` output for automation or parsing. Preserve the unfiltered JSON when the observed schema differs from the expected shape.

## Authoritative references

- [Azure CLI: work items](https://learn.microsoft.com/en-us/cli/azure/boards/work-item?view=azure-cli-latest)
- [Azure CLI: work-item relations](https://learn.microsoft.com/en-us/cli/azure/boards/work-item/relation?view=azure-cli-latest)
- [Azure CLI: pull requests](https://learn.microsoft.com/en-us/cli/azure/repos/pr?view=azure-cli-latest)
- [Azure CLI: pipelines](https://learn.microsoft.com/en-us/cli/azure/pipelines?view=azure-cli-latest) and [pipeline runs](https://learn.microsoft.com/en-us/cli/azure/pipelines/runs?view=azure-cli-latest)
- [Azure CLI: project iterations](https://learn.microsoft.com/en-us/cli/azure/boards/iteration/project?view=azure-cli-latest) and [team iterations](https://learn.microsoft.com/en-us/cli/azure/boards/iteration/team?view=azure-cli-latest)
- [Azure CLI: `az devops invoke`](https://learn.microsoft.com/en-us/cli/azure/devops?view=azure-cli-latest#az-devops-invoke)
- [Azure DevOps REST 7.1: work-item comments](https://learn.microsoft.com/en-us/rest/api/azure/devops/wit/comments/get-comments?view=azure-devops-rest-7.1)
- [Azure DevOps REST 7.1: work-item revisions](https://learn.microsoft.com/en-us/rest/api/azure/devops/wit/revisions/list?view=azure-devops-rest-7.1)
- [Azure DevOps REST 7.1: work-item update deltas](https://learn.microsoft.com/en-us/rest/api/azure/devops/wit/updates/list?view=azure-devops-rest-7.1)
- [Azure DevOps REST 7.1: attachment downloads](https://learn.microsoft.com/en-us/rest/api/azure/devops/wit/attachments/get?view=azure-devops-rest-7.1)
- [Azure DevOps REST 7.1: build timeline](https://learn.microsoft.com/en-us/rest/api/azure/devops/build/timeline/get?view=azure-devops-rest-7.1) and [build logs](https://learn.microsoft.com/en-us/rest/api/azure/devops/build/builds/get-build-logs?view=azure-devops-rest-7.1)
- [Azure DevOps REST 7.1: pull-request threads](https://learn.microsoft.com/en-us/rest/api/azure/devops/git/pull-request-threads?view=azure-devops-rest-7.1)

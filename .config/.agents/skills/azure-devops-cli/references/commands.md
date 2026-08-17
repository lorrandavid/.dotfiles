# Azure DevOps command reference

Use these patterns after the core workflow in `SKILL.md`. Examples are single-line to avoid shell-specific continuation syntax. Replace every placeholder, quote substituted values for the active shell, and retain `--only-show-errors --output json` for data operations.

## Contents

- [Shared inspection](#shared-inspection)
- [Formatting-safe writes](#formatting-safe-writes)
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

## Formatting-safe writes

Apply this protocol to descriptions, comments, acceptance criteria, reproduction steps, release notes, custom multiline fields, and every other human-authored value where whitespace or markup matters. It applies even when another skill prepared the content.

1. Identify the destination's native format before writing:
   - PR descriptions and PR comments: Markdown.
   - Work-item comments through the comments API: Markdown when `format=markdown` is explicit.
   - Work-item fields whose metadata type is `html`, including the usual Description, Acceptance Criteria, and Repro Steps fields: HTML. Raw Markdown in these fields is plain text, so convert the intended Markdown to equivalent HTML before mutation.
   - Fields whose metadata type is `plainText` or `string`: plain text. Do not promise Markdown rendering.
2. Preserve the authored source in a temporary UTF-8 file. Use LF or CRLF consistently and do not add a byte-order mark. Inspect the complete file before mutation. Do not construct rich content with `echo`, shell interpolation, a command-line here-document, or literal `\n` sequences.
3. For REST bodies, create valid JSON with a JSON-aware editing or serialization tool so quotes, backslashes, newlines, and non-ASCII characters are escaped correctly. Pass the body with `az devops invoke --in-file`; never interpolate Markdown or HTML into JSON in the shell.
4. For first-class commands that accept only a string argument, load the entire file into one native shell variable and pass that variable as one argument. Do not paste the content into the command.
5. Read the written resource back through an unfiltered endpoint. For Markdown, compare the raw stored value with the intended payload after normalizing CRLF/LF and, only when the client removed it, one terminal newline. For HTML fields, verify that the server-stored HTML retains the intended headings, paragraphs, lists, tables, code, and links after Azure DevOps sanitation. Also verify the destination format when the API exposes it. If text or structure is missing or escaped incorrectly, treat the mutation as failed and correct it before reporting success.
6. Remove temporary payload files after successful verification when they contain sensitive or task-specific content. Do not delete user-authored source files.

Use these shell-specific file-to-one-argument patterns. Both preserve embedded quotes, backticks, dollar signs, and real line breaks because the shell does not re-evaluate variable contents.

Bash:

```text
content="$(<content.md)"
az <command> --description "$content" ...
```

Windows PowerShell 5.1 or PowerShell 7+:

```text
$content = [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath './content.md').Path)
az <command> --description $content ...
```

Do not use Bash command substitution in PowerShell or PowerShell `Get-Content` syntax in Bash. Keep command examples single-line after assigning the variable.

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

For a title-only or otherwise simple scalar create, the first-class command is acceptable:

```text
az boards work-item create --org <org-url> --project <project> --type <work-item-type> --title <title> --only-show-errors --output json
```

When creation includes a description, acceptance criteria, custom multiline fields, or several coupled properties, inspect field metadata and write one JSON Patch array to a UTF-8 file. Include one `add` operation per requested field, using its reference name:

```json
[
  { "op": "add", "path": "/fields/System.Title", "value": "<title>" },
  { "op": "add", "path": "/fields/System.Description", "value": "<native HTML>" },
  { "op": "add", "path": "/fields/<field-reference-name>", "value": "<typed value>" }
]
```

Create the item with that payload:

```text
az devops invoke --area wit --resource workItems --route-parameters project=<project> type=<work-item-type> --org <org-url> --api-version 7.1 --http-method POST --media-type application/json-patch+json --in-file <work-item-patch.json> --only-show-errors --output json
```

Pass only requested fields. Process-specific reference names and types vary; never guess them. Render Markdown source to equivalent HTML for an `html` field. Verify every field from an expanded work-item read. Do not use a lossy first-class create followed by field repairs when this endpoint can create the requested state in one request.

### Update — mutating

Read the current item, then update only requested fields:

```text
az boards work-item update --id <work-item-id> --org <org-url> --title <title> --state <state> --assigned-to <identity> --iteration <iteration-path> --fields <field-reference-name>=<value> --only-show-errors --output json
```

Add a discussion comment:

```json
{
  "text": "<Markdown with JSON-escaped line breaks>"
}
```

Write that object to a UTF-8 JSON file, then use the comments API with its format declared explicitly:

```text
az devops invoke --area wit --resource comments --route-parameters project=<project> workItemId=<work-item-id> --query-parameters 'format=markdown' --org <org-url> --api-version 7.1-preview.4 --http-method POST --in-file <comment.json> --only-show-errors --output json
```

Classify discussion updates as `work-item.comment`. Do not use `az boards work-item update --discussion` for formatted content because it does not declare the content format. Read the returned comment and then fetch it through the comments API; verify `format` is `markdown`, `text` matches the source, and `renderedText` is present. Read the item back after creation or field updates.

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

For a run just queued in the current operation, use the queue response as the initial observation and do not immediately fetch the run again. For a pre-existing run without a current observation, read it once immediately. Then poll until `status` is `completed`:

```text
az pipelines runs show --id <run-id> --project <project> --org <org-url> --only-show-errors --output json
```

Use a polling interval, not a debounce: a debounce can postpone forever while events keep arriving, whereas polling guarantees one bounded request per interval. After the initial observation, apply this schedule:

- Wait 5 minutes before the first follow-up read.
- If the run is not completed, wait 10 minutes before the second follow-up read.
- If the run is still not completed, wait 15 minutes before every later read.
- If the service returns throttling or transient-unavailable guidance, honor `Retry-After` when it requires a longer delay than the schedule.

Record the next eligible poll time and make no run, timeline, log, pipeline-list, or recent-runs request merely to fill the wait. A user-requested or repository-defined slower interval overrides this schedule. Do not poll sooner unless an explicit repository contract requires it. Historical run durations may provide a rough ETA, but must not replace checking the captured run ID or be used to assume completion; querying history solely to choose a delay adds load without establishing current state.

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

Use `az repos pr create` only for a simple PR whose requested state is fully represented by reliable scalar arguments. If creation includes a multiline description, draft mode, work-item links, or reviewers, create it atomically through the Git REST resource. Resolve the repository ID and reviewer identity IDs first. Generate this body in a UTF-8 JSON file with a JSON-aware serializer; omit properties the user did not request:

```json
{
  "sourceRefName": "refs/heads/<source-branch>",
  "targetRefName": "refs/heads/<target-branch>",
  "title": "<title>",
  "description": "<multiline Markdown>",
  "isDraft": true,
  "workItemRefs": [
    { "id": "<work-item-id-1>" },
    { "id": "<work-item-id-2>" }
  ],
  "reviewers": [
    { "id": "<reviewer-identity-id>", "isRequired": false },
    { "id": "<required-reviewer-identity-id>", "isRequired": true }
  ]
}
```

Then make one create request:

```text
az devops invoke --area git --resource pullRequests --route-parameters project=<project> repositoryId=<repository-id> --org <org-url> --api-version 7.1 --http-method POST --in-file <pull-request.json> --only-show-errors --output json
```

Use full `refs/heads/...` ref names in the REST body. Do not create the PR first and then repair its description, draft state, work-item links, or reviewers when they can be included in this payload. Do not enable auto-complete, policy bypass, source-branch deletion, or work-item transitions unless explicitly requested.

Read the PR back unfiltered and separately list linked work items and reviewers. Verify the title, source and target refs, raw description, `isDraft`, linked work-item IDs, reviewer IDs, and required-reviewer flags before reporting success.

### Update — mutating or high-impact

A simple scalar metadata update may use `az repos pr update`. For multiline Markdown or an update combining several properties, write only the requested properties to a UTF-8 JSON file and use one REST PATCH:

```json
{
  "title": "<title>",
  "description": "<multiline Markdown>",
  "isDraft": false
}
```

```text
az devops invoke --area git --resource pullRequests --route-parameters project=<project> repositoryId=<repository-id> pullRequestId=<pr-id> --org <org-url> --api-version 7.1 --http-method PATCH --in-file <pull-request-update.json> --only-show-errors --output json
```

Do not include unchanged or unrequested properties. After creating or updating a PR, read its unfiltered state back from the server. Compare the raw description with the rendered Markdown, verify that headings remain on separate lines and that the value contains no literal `\n` sequences, and verify every other requested property. If verification fails, treat the update as failed; re-read before deciding whether a corrective request is safe.

Treat completion, abandonment, policy bypass, source-branch deletion, and work-item transitions as high-impact regardless of transport. Read policies and merge status immediately before completing a PR, and read the PR back afterward.

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

To create a top-level PR comment, keep the Markdown source in a UTF-8 file and write this request body to a separate temporary UTF-8 JSON file with a JSON-aware tool:

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

Read the created thread back and compare `comments[0].content` with the Markdown source using the shared normalization rule. Do not report success from the POST response alone.

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
- [Azure DevOps REST 7.1: add a formatted work-item comment](https://learn.microsoft.com/en-us/rest/api/azure/devops/wit/comments/add-work-item-comment?view=azure-devops-rest-7.1)
- [Azure DevOps REST 7.1: work-item field types](https://learn.microsoft.com/en-us/rest/api/azure/devops/wit/fields/list?view=azure-devops-rest-7.1)
- [Azure DevOps REST 7.1: work-item revisions](https://learn.microsoft.com/en-us/rest/api/azure/devops/wit/revisions/list?view=azure-devops-rest-7.1)
- [Azure DevOps REST 7.1: work-item update deltas](https://learn.microsoft.com/en-us/rest/api/azure/devops/wit/updates/list?view=azure-devops-rest-7.1)
- [Azure DevOps REST 7.1: attachment downloads](https://learn.microsoft.com/en-us/rest/api/azure/devops/wit/attachments/get?view=azure-devops-rest-7.1)
- [Azure DevOps REST 7.1: build timeline](https://learn.microsoft.com/en-us/rest/api/azure/devops/build/timeline/get?view=azure-devops-rest-7.1) and [build logs](https://learn.microsoft.com/en-us/rest/api/azure/devops/build/builds/get-build-logs?view=azure-devops-rest-7.1)
- [Azure DevOps REST 7.1: pull-request threads](https://learn.microsoft.com/en-us/rest/api/azure/devops/git/pull-request-threads?view=azure-devops-rest-7.1)

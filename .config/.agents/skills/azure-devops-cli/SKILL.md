---
name: azure-devops-cli
description: Operate Azure DevOps through the Azure CLI for Boards work items, requirement history, comments, revisions, attachments, relations, backlog and sprint queries, Pipeline definitions, runs, timelines and logs, and Repos pull requests, reviewers, policies, votes, conflict status, and work-item links. Use for read-only ADO inspection or explicitly requested mutations such as creating or updating work items and PRs or queuing a pipeline run.
---

# Azure DevOps CLI

Prefer Azure CLI authentication and resource discovery over manual web instructions. Use first-class `az boards`, `az pipelines`, and `az repos` commands for reads and simple scalar mutations. For creates or updates that combine multiline text with flags, links, relations, reviewers, or other coupled fields, prefer one REST request through `az devops invoke --in-file` even when a first-class command exists. The Azure DevOps extension's argument adapters can silently reshape multiline values or omit coupled fields.

Read [references/commands.md](references/commands.md) before executing an ADO operation.

## Operating contract

- Return command-backed data only; never invent ADO state, identities, IDs, links, policies, or permissions.
- Resolve organization, project, repository, team, and resource IDs before mutation. Read current state first when it affects the change.
- Derive project, repository, and related scope from supplied work-item or PR IDs when ADO can return it; ask only for values that cannot be discovered safely.
- Before choosing a work-item state, discover the states configured for that item's project and work-item type. Never assume that `Active`, `Doing`, `Resolved`, or `Done` exists across projects or types.
- Prefer names for user-facing output and IDs for commands and joins.
- Add `--only-show-errors --output json` to data commands unless the user explicitly requests a table.
- Use JMESPath `--query` only to reduce or normalize output; do not discard fields needed to verify a mutation.
- Follow every pagination mechanism until complete unless the user requests a limit. Report page counts, completion, and any continuation token or offset when output is truncated.
- Rate-limit every wait loop. Treat a successful create/queue response containing the resource's current state as the initial observation; do not immediately read the same resource again. After the initial observation, use the operation-specific interval in `references/commands.md`; when none is documented, wait 5 minutes before the first follow-up read, 10 minutes before the second, and 15 minutes before every later read. Never issue back-to-back status reads while waiting, and honor server retry guidance when it requires a longer delay.
- Treat the comments API as the authoritative work-item discussion history. `System.History`, revisions, and update deltas complement comments but do not replace them.
- Preserve structured text on every mutation. Classify the destination as Markdown, HTML, or plain text; render into that native format; transport multiline content from a UTF-8 file; and read the stored value back. Follow the formatting protocol in `references/commands.md`. Never pass rich content as an inline shell literal, literal `\n` text, or an unverified `--fields` value.
- Choose the mutation transport before writing. If one REST create/update endpoint accepts all requested properties, send one JSON or JSON Patch payload with `az devops invoke --in-file`; do not knowingly create a partial resource with a first-class command and then repair it server-side. Use multiple mutations only when ADO exposes no atomic endpoint, and state that limitation before the first write.
- Treat a successful CLI exit as transport success, not field-level success. Verify every requested field, flag, reviewer, relation, and link from server state. If verification fails unexpectedly, report the mismatch and obtain a fresh read before deciding whether a corrective mutation is safe; do not normalize create-then-correct as the standard workflow.
- Never expose PATs, authorization headers, environment variables, or credential-store contents.
- Do not use `--open` in unattended work or when a URL is sufficient.

## Classify every operation

State the classification internally before running commands and include it in structured results.

### Read-only

Commands that only inspect state: `show`, `list`, `query`, `relation show`, `relation list-type`, work-item comments/revisions/updates/attachment metadata, pipeline definition/run/timeline/log reads, PR reviewer/work-item/policy lists, iteration queries, `az devops configure --list`, and GET requests through `az devops invoke`.

Run read-only commands without confirmation when their scope is clear.

Attachment download is read-only in ADO but writes a local artifact. Download only when requested or required for the task, use an explicit workspace destination, report that path, and never execute downloaded content automatically.

### Mutating

Commands that create or change recoverable collaboration state: create/update work items or PRs, transition work-item states, queue pipeline runs, add discussions or PR comments, add/remove relations or linked work items, add/remove reviewers, set/reset votes, queue policy evaluation, and update iteration/team configuration.

Before mutation:

1. Require exact target scope and requested change.
2. Read the target when its current state or revision matters.
3. Summarize the intended mutation and affected IDs.
4. Execute without redundant confirmation when the user already requested that exact mutation; otherwise ask.
5. Read back the result and report the final server state.

### High-impact

Treat PR completion/abandonment, policy bypass, source-branch deletion, terminal work-item transitions, work-item deletion, permanent destruction, and bulk mutations as high-impact. Require explicit authorization naming the action and target. Never infer these actions from “finish,” “clean up,” or similar wording.

## Work-item lifecycle states

Treat state selection as semantic matching, not a hard-coded string lookup:

1. Read the item and capture its project, work-item type, current state, and revision.
2. List the states configured for that exact project and type, preserving each state's `name`, `category`, and customization metadata.
3. Prefer a repository tracker contract's explicit mapping for the lifecycle moment. Otherwise choose only a state whose name and category clearly express that moment.
4. For work starting, choose a configured `InProgress` state. For review readiness, prefer an explicit review state; otherwise keep an `InProgress` state rather than treating a draft PR as completed. For blockage, choose an explicit blocked/on-hold state only when configured; otherwise preserve the current state and report the limitation. Never use a `Completed` or `Removed` state merely because work paused, failed, or reached a draft PR.
5. If multiple equally suitable states remain, do not guess: return the candidates and ask the caller. If no suitable state exists, leave the item unchanged.
6. Update only when the chosen state differs from the current state. Read the item back and verify the exact state and new revision. On a rule-validation or revision conflict, re-read the item and state catalog before deciding whether another transition is valid; never hop through intermediate states speculatively.

Include the lifecycle moment, discovered candidates, selection rationale, previous state, requested state, final state, and verification status in the normalized result. State discovery is read-only; a transition is mutating. Closing, removing, or otherwise terminally transitioning an item requires explicit authorization even when the terminal state is available.

## Prerequisites

Check the extension, defaults, and authentication before ADO work:

```text
az extension show --name azure-devops --output json
az devops configure --list --output json
```

Install the extension only when missing and with user approval if installation is outside the current environment:

```text
az extension add --name azure-devops
```

Configure defaults when stable for the repository:

```text
az devops configure --defaults organization=https://dev.azure.com/<org> project=<project>
```

Use the existing `az login` session or `az devops login --organization <org-url>` as appropriate. Do not request a PAT in chat; direct the user to authenticate through a secure interactive mechanism.

## Workflow

1. Classify the request as work item, work-item state discovery/transition, requirement history/attachment, relation/link, pipeline definition/run/log, PR, PR comment, policy/reviewer/vote, or sprint/iteration.
2. Classify it as read-only, mutating, or high-impact.
3. Resolve and verify defaults plus missing organization/project/repository/team/resource identifiers.
4. Read current state when needed. For a lifecycle transition, discover the exact type's configured state catalog and select semantically before mutation.
5. For human-authored text, apply the formatting protocol and inspect the exact payload before mutation.
6. Select the transport: use one file-backed REST payload for a compound or rich-text mutation; otherwise use the narrowest reliable first-class command from the command reference.
7. For mutation, read back the affected resource and compare every requested field, flag, reviewer, relation, and link. For formatted text, verify the raw stored value and its destination format before reporting success.
8. Return concise human output plus normalized JSON when requested or when another tool will consume the result.

## Output contract

Prefer portal URLs over REST URLs in user-facing output. If Azure returns `_links.web.href` or another explicit portal URL, use it. Otherwise synthesize:

- Work item: `<org-url>/<encoded-project>/_workitems/edit/<work-item-id>`
- Pull request: `<org-url>/<encoded-project>/_git/<encoded-repository>/pullrequest/<pr-id>`

Remove a trailing slash from `<org-url>` and percent-encode each path segment. Do not synthesize sprint URLs; return a portal link only when ADO provides one.

For machine-readable output, normalize to this envelope while preserving the raw command result when fields are uncertain:

```json
{
  "operation": "work-item.show",
  "classification": "read-only",
  "organization": "https://dev.azure.com/example",
  "project": "Example Project",
  "repository": null,
  "count": 1,
  "results": [
    {
      "id": 123,
      "title": "Example",
      "state": "Active",
      "url": "https://dev.azure.com/example/Example%20Project/_workitems/edit/123"
    }
  ]
}
```

Use stable operation names such as `work-item.create`, `work-item.update`, `work-item.state.list`, `work-item.state.transition`, `work-item.comment`, `work-item.comments.list`, `work-item.revisions.list`, `work-item.updates.list`, `work-item.attachments.list`, `work-item.attachment.download`, `requirement.snapshot`, `work-item.link`, `pipeline.list`, `pipeline.run.queue`, `pipeline.run.show`, `pipeline.run.timeline`, `pipeline.run.log`, `pr.show`, `pr.update`, `pr.comment`, `pr.vote`, `pr.policy.list`, and `iteration.current`.

For paged operations, add a sibling `pagination` object per collection:

```json
{
  "complete": true,
  "pagesFetched": 3,
  "itemsFetched": 247,
  "continuationToken": null,
  "nextOffset": null,
  "limitRequested": null
}
```

Set `complete` to `false` when a requested limit, error, or interrupted fetch leaves more server data available. Never label a first page as a complete history.

## Error handling

- Report the exact CLI or REST error and command category without exposing secrets.
- Distinguish missing parameters, authentication, authorization, validation rules, revision conflicts, and unsupported commands.
- On mutation failure, read the resource before retrying; the first request may have partially succeeded.
- Do not retry non-idempotent mutations blindly.
- Treat pipeline queueing as non-idempotent. Capture the returned run ID; after an ambiguous response, inspect recent runs for an exact definition, branch, and source-version match before queueing again.
- If `az devops invoke` cannot resolve an area/resource, discover available resources with a read-only `az devops invoke` query before changing the route.

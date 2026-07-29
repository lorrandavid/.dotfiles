---
name: azure-devops-cli
description: Operate Azure DevOps through the Azure CLI for Boards work items, requirement history, comments, revisions, attachments, relations, backlog and sprint queries, Pipeline definitions, runs, timelines and logs, and Repos pull requests, reviewers, policies, votes, conflict status, and work-item links. Use for read-only ADO inspection or explicitly requested mutations such as creating or updating work items and PRs or queuing a pipeline run.
---

# Azure DevOps CLI

Prefer `az boards`, `az pipelines`, `az repos`, and `az devops` over manual web instructions. Use `az devops invoke` only when the extension has no first-class command, notably for pipeline timelines and logs or pull-request comment threads.

Read [references/commands.md](references/commands.md) before executing an ADO operation.

## Operating contract

- Return command-backed data only; never invent ADO state, identities, IDs, links, policies, or permissions.
- Resolve organization, project, repository, team, and resource IDs before mutation. Read current state first when it affects the change.
- Derive project, repository, and related scope from supplied work-item or PR IDs when ADO can return it; ask only for values that cannot be discovered safely.
- Prefer names for user-facing output and IDs for commands and joins.
- Add `--only-show-errors --output json` to data commands unless the user explicitly requests a table.
- Use JMESPath `--query` only to reduce or normalize output; do not discard fields needed to verify a mutation.
- Follow every pagination mechanism until complete unless the user requests a limit. Report page counts, completion, and any continuation token or offset when output is truncated.
- Treat the comments API as the authoritative work-item discussion history. `System.History`, revisions, and update deltas complement comments but do not replace them.
- Never expose PATs, authorization headers, environment variables, or credential-store contents.
- Do not use `--open` in unattended work or when a URL is sufficient.

## Classify every operation

State the classification internally before running commands and include it in structured results.

### Read-only

Commands that only inspect state: `show`, `list`, `query`, `relation show`, `relation list-type`, work-item comments/revisions/updates/attachment metadata, pipeline definition/run/timeline/log reads, PR reviewer/work-item/policy lists, iteration queries, `az devops configure --list`, and GET requests through `az devops invoke`.

Run read-only commands without confirmation when their scope is clear.

Attachment download is read-only in ADO but writes a local artifact. Download only when requested or required for the task, use an explicit workspace destination, report that path, and never execute downloaded content automatically.

### Mutating

Commands that create or change recoverable collaboration state: create/update work items or PRs, queue pipeline runs, add discussions or PR comments, add/remove relations or linked work items, add/remove reviewers, set/reset votes, queue policy evaluation, and update iteration/team configuration.

Before mutation:

1. Require exact target scope and requested change.
2. Read the target when its current state or revision matters.
3. Summarize the intended mutation and affected IDs.
4. Execute without redundant confirmation when the user already requested that exact mutation; otherwise ask.
5. Read back the result and report the final server state.

### High-impact

Treat PR completion/abandonment, policy bypass, source-branch deletion, work-item deletion, permanent destruction, and bulk mutations as high-impact. Require explicit authorization naming the action and target. Never infer these actions from “finish,” “clean up,” or similar wording.

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

1. Classify the request as work item, requirement history/attachment, relation/link, pipeline definition/run/log, PR, PR comment, policy/reviewer/vote, or sprint/iteration.
2. Classify it as read-only, mutating, or high-impact.
3. Resolve and verify defaults plus missing organization/project/repository/team/resource identifiers.
4. Read current state when needed, then run the narrowest command from the command reference.
5. For mutation, read back the affected resource and compare the requested fields or links.
6. Return concise human output plus normalized JSON when requested or when another tool will consume the result.

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

Use stable operation names such as `work-item.create`, `work-item.update`, `work-item.comment`, `work-item.comments.list`, `work-item.revisions.list`, `work-item.updates.list`, `work-item.attachments.list`, `work-item.attachment.download`, `requirement.snapshot`, `work-item.link`, `pipeline.list`, `pipeline.run.queue`, `pipeline.run.show`, `pipeline.run.timeline`, `pipeline.run.log`, `pr.show`, `pr.update`, `pr.comment`, `pr.vote`, `pr.policy.list`, and `iteration.current`.

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

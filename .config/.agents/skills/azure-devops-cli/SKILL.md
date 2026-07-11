---
name: azure-devops-cli
description: Use Azure DevOps CLI for ADO work items, backlog filtering, and pull requests.
argument-hint: "[ado request]"
---

Use this skill whenever the user asks for Azure DevOps (ADO) operations like Boards, Work Items, Backlog filtering, Repositories, or Repos Pull Requests.

## Rules

- Prefer Azure DevOps CLI commands (`az boards`, `az repos`, `az devops`) over manual or web instructions.
- Never invent ADO data. Always return command-backed results.
- If required inputs are missing (organization, project, repo, work item IDs), gather them before running mutating commands.

## Prerequisites

1. Ensure Azure DevOps extension is installed:
   ```bash
   az extension add --name azure-devops
   ```
2. Ensure defaults are configured when possible:
   ```bash
   az devops configure --defaults organization=<https://dev.azure.com/org> project=<project>
   ```
3. Ensure user is authenticated (`az login`) and, when needed, logged into ADO:
   ```bash
   az devops login --organization <https://dev.azure.com/org>
   ```

## Workflow

1. Classify request into one of: work item read/query, backlog filtering, PR operations.
2. Confirm current defaults before executing:
   ```bash
   az devops configure --list
   ```
3. Run the matching command set.
4. Return concise results (IDs, titles, states, links when available) and next-step options.

## Command Patterns

### Get work item or user story by ID

```bash
az boards work-item show --id <work_item_id> --output json
```

### Query user stories / work items (WIQL)

```bash
az boards query --wiql "SELECT [System.Id], [System.Title], [System.State]
FROM WorkItems
WHERE [System.TeamProject] = @project
  AND [System.WorkItemType] IN ('User Story','Task','Bug')
ORDER BY [System.ChangedDate] DESC" --output table
```

### Filter backlog (example: active items assigned to me)

```bash
az boards query --wiql "SELECT [System.Id], [System.Title], [System.State], [System.AssignedTo]
FROM WorkItems
WHERE [System.TeamProject] = @project
  AND [System.WorkItemType] IN ('User Story','Task','Bug')
  AND [System.State] <> 'Closed'
  AND [System.AssignedTo] = @Me
ORDER BY [System.ChangedDate] DESC" --output table
```

### Create pull request

```bash
az repos pr create \
  --repository <repo_name_or_id> \
  --source-branch <source_branch> \
  --target-branch <target_branch> \
  --title "<title>" \
  --description "<description>"
```

### List pull requests

```bash
az repos pr list --repository <repo_name_or_id> --status active --output table
```

## Error Handling

- If a command fails, report the exact CLI error and identify the missing parameter or permission.
- For create/update commands, confirm scope (project/repo/branch) before execution.
- Prefer read-only commands first when context is uncertain.
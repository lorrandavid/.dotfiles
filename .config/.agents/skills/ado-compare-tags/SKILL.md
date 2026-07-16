---
name: ado-compare-tags
description: Compare two Git tags in an Azure DevOps repository, identify merged pull requests reachable from only one tag, collect each PR's linked work items, roll Tasks and User Stories/Product Backlog Items up to Features, and produce a release-difference summary. Use when Codex must explain which Features, User Stories, PBIs, Requirements, or Tasks were introduced, removed, or differ between two Azure Repos tags.
---

# Compare Azure DevOps Tags

Treat the operation as read-only. Use the bundled script for deterministic Git and Azure DevOps joins, then summarize its JSON result.

## Inputs

Require exactly three positional values in this order:

1. Azure DevOps repository URL
2. Base tag
3. Target tag

Interpret the target side as “changes present in the target tag but absent from the base tag.” Also report the reverse side. This makes diverged tags explicit and prevents a misleading one-way release report.

Accept HTTPS or SSH Azure Repos URLs. Ask only for a missing value; do not ask for organization, project, or repository names that can be parsed from the URL and verified through Azure DevOps.

## Run the comparison

1. Verify that `git`, Azure CLI, and the `azure-devops` CLI extension are available. Use the current authenticated session. Never request or expose a PAT.
2. Run:

   ```text
   python <skill-directory>/scripts/compare_ado_tags.py <repository-url> <base-tag> <target-tag>
   ```

3. Capture stdout as JSON. Leave stderr visible for progress and diagnostics.
4. If authentication is missing, direct the user to authenticate securely and rerun. Installing the Azure DevOps extension requires the user's approval when it changes their environment.

The script fetches only the two tags, computes both commit-set differences, resolves PRs through Azure DevOps's `lastMergeCommit` query, obtains directly linked work items, follows parent hierarchy links, and deduplicates all entities. Do not replace it with PR-title parsing or commit-message heuristics.

## Read the result

Use these result sections:

- `comparison.relationship`: whether the base is an ancestor of the target, the target is an ancestor of the base, the tags diverged, or both resolve to the same commit.
- `sides.targetOnly`: merged PRs and work items present only in the target tag.
- `sides.baseOnly`: merged PRs and work items present only in the base tag.
- `pullRequests[].directWorkItemIds`: work items attached directly to a PR.
- `pullRequests[].workItemPaths`: each directly linked item followed by its parent chain.
- `workItems[].category`: normalized as `feature`, `story`, `task`, or `other`. Treat User Story, Product Backlog Item, and Requirement as `story` while preserving `type`.
- `unmatchedCommits`: commits for which Azure DevOps did not return a PR whose `lastMergeCommit` matched. These may be direct commits, cherry-picks, rewritten history, or merge strategies that cannot be traced by this query.
- `completeness`: collection status and warnings. Never describe an incomplete result as exhaustive.

## Produce the report

Lead with the directional result: “In `<target-tag>` but not `<base-tag>`.” Group by Feature, then show child User Stories/PBIs/Requirements and Tasks. For every item include its ID, title, state, and linked PR IDs. Summarize descriptions and acceptance criteria when present; do not infer business behavior from titles alone.

Use this compact structure:

```markdown
# Tag comparison: <base> → <target>

## Summary
<relationship, counts, and the main business capabilities moving forward>

## In target only
### Feature #<id>: <title>
<one- or two-sentence feature summary>
- Story #<id>: <title> — <state> — PR #<id>
  - Task #<id>: <title> — <state>

### Unparented work items
<directly linked stories/tasks with no discovered Feature ancestor>

## In base only
<same structure; say “None” when empty>

## Traceability gaps
<PRs without work items, unmatched commits, fetch warnings, or incomplete collections>
```

Link PRs and work items using the portal URLs supplied by the script. Deduplicate a work item that appears on multiple PRs and list all contributing PR IDs. Keep `baseOnly` visible even when empty.

## Accuracy rules

- Report command-backed Azure DevOps data only.
- Treat tag membership as Git reachability, not chronological completion dates.
- Include completed PRs only; the commit-to-PR query is authoritative for the merge commit association.
- Call a work item “directly linked” only when Azure DevOps returns it from the PR work-item endpoint. Label discovered parents as hierarchy-derived.
- Do not silently drop custom work-item types; place them under `other` and preserve their hierarchy.
- Mention unmatched commits and PRs without linked work items because they limit release-note completeness.
- If the tags diverged, describe both sides as independent differences rather than implying that target is a later release.

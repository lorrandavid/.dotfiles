---
name: pr-checkout
description: Fetch and checkout a pull request by its number.
---

# PR Checkout Skill 

Skill to fetch and checkout a pull request by its number specific to git repositories.

## When to use

Use this skill when you need to fetch and checkout a specific pull request in a git repository by providing its PR number. Or when the user mentions `checkout PR <number>`.

## Parameters

- `pr_number` (integer, required): The number of the pull request to checkout.

## Workflow

1. Fetch the pull request using the provided PR number: `git fetch origin pull/<pr_number>/merge:pr-<pr_number>`
2. Checkout the fetched pull request branch: `git checkout pr-<pr_number>`

## Example Usage

To checkout pull request number 42:

```bash
git fetch origin pull/42/merge:pr-42
git checkout pr-42
```

## Verification

After executing the commands, verify that you are on the correct branch by running:

```bash
git branch --show-current
```

It must return `pr-<pr_number>`, confirming that you have successfully checked out the pull request.

## Error Handling

- If the pull request does not exist or the fetch fails, handle the error gracefully by informing the user that the specified PR number is invalid or cannot be fetched.
- If the checkout fails, inform the user and suggest checking for merge conflicts or other issues.

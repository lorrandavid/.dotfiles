---
name: release-manager
description: Compares the current production version with an upcoming release, assesses risk, and produces both a technical release report and human-readable release notes.
argument-hint: "[base_version] [target_version]"
disable-model-invocation: true
---

This skill gathers inputs for a release comparison and delegates the work to the release-manager agent.

----------------------------------------
WORKFLOW YOU MUST FOLLOW
----------------------------------------

1) Parse `/release-manager <base_version> <target_version>` into:
   - base_version: $0
   - target_version: $1

2) Gather commit_log: commit history between base_version and target_version

3) Invoke ONE (1) @release-manager subagent (using GPT-5.2-Codex High) with:
   - base_version
   - target_version
   - commit_log

   The agent will read changed files directly rather than relying on raw diffs.

4) Return the agent's response as the final output (no extra messages or confirmations)

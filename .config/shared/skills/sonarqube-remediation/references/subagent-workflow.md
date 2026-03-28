# Subagent workflow

Use subagents to keep Sonar acquisition and broad triage out of the main agent's context window.

## Default split

Run the first two in parallel when they use the same `project-key` and independent filters:

1. Summary subagent
2. Issues subagent
3. Optional code-mapping subagent
4. Optional remediation subagent

The main agent should merge results, choose the candidate fix set, and own the final recommendation.

## Summary subagent template

Use an execution-oriented subagent, preferably a `task` agent, when you need project-level measures or quality gate state.

Prompt shape:

```text
Work in <repo-path>.

Run:
python3 .config/shared/skills/sonarqube-remediation/scripts/sonar_fetch_summary.py --project-key <project-key> [--branch <branch>] [--pull-request <pr>]

Return:
- raw compact JSON
- one short list of risk flags worth carrying into remediation

Important:
- rely on existing SONARQUBE_URL and SONARQUBE_TOKEN environment variables
- do not print, copy, or restate secret values
- if env vars are missing or the helper output looks inconsistent with Sonar data, stop and report that explicitly
```

## Issues subagent template

Use an execution-oriented subagent, preferably a `task` agent, when you need a narrow, reproducible issue list.

Prompt shape:

```text
Work in <repo-path>.

Run:
python3 .config/shared/skills/sonarqube-remediation/scripts/sonar_fetch_issues.py --project-key <project-key> --types <types> --statuses <statuses> [--severities <severities>] [--branch <branch>] [--pull-request <pr>] [--max-pages <n>]

Return:
- filtered issue list
- for each issue: key, rule, severity, component/file, line, message
- a short recommendation on which issues are safe to consider first

Important:
- prefer explicit issue keys from the caller when provided
- do not widen scope beyond requested filters without saying so
- stop if results appear incomplete, contradictory, or not locally actionable
```

## Code-mapping subagent template

Use an explore-style subagent when Sonar output needs local repo interpretation.

Prompt shape:

```text
Explore the local repo in <repo-path> for the Sonar findings below.

Return:
- files or modules involved
- existing implementation patterns to follow
- any risk multipliers such as auth, crypto, migrations, concurrency, or public API exposure

Do not propose patches yet. This step is only for mapping and risk assessment.
```

## Remediation handoff template

Use a code-changing subagent only after the main agent has chosen a small, conservative target.

Prompt shape:

```text
Implement only the approved Sonar fix in <repo-path>.

Inputs:
- selected issue(s)
- allowed scope
- required validation commands

Return:
- patch summary
- validation results
- any follow-up risks or unresolved findings

Do not expand scope beyond the approved issue set.
```

## Duplication subagent template

Use an execution-oriented subagent, preferably a `task` agent, to gather duplication data.

Prompt shape:

```text
Work in <repo-path>.

Run:
python3 .config/shared/skills/sonarqube-remediation/scripts/sonar_fetch_duplications.py --project-key <project-key> [--branch <branch>] [--max-files <n>] [--buffer-percent <pct>]

Return:
- raw compact JSON
- one-line summary: total LOC, total duplicated lines, effective lines to remove
- the top 5 files by duplicated line count with their peer components

Important:
- rely on existing SONARQUBE_URL and SONARQUBE_TOKEN environment variables
- do not print, copy, or restate secret values
- if env vars are missing or the helper output looks inconsistent with Sonar data, stop and report that explicitly
```

## Duplication code-mapping subagent template

After the duplication data is gathered, use an explore-style subagent to map duplication blocks to local code.

Prompt shape:

```text
Explore the local repo in <repo-path> for the following duplication findings from SonarQube.

For each duplicated file:
1. Read the duplicated lines in the source file (lines <from_line> to <from_line + size>)
2. Read the same lines in the peer component
3. Search the codebase for an existing shared solution (utility, base class, shared module, service) that already handles this logic
4. Note whether the duplication is in a sensitive area (auth, crypto, migrations, concurrency)

Return for each duplication group:
- the actual duplicated code snippet (abbreviated if large)
- the peer component path
- whether an existing shared solution was found (and where)
- risk assessment (safe to consolidate, needs caution, do not auto-fix)
- suggested consolidation approaches if no shared solution exists:
  a. Extract shared utility/service
  b. Base class or mixin
  c. Composition/delegation
  d. Accept the duplication (if coupling cost outweighs benefit)

Do not propose patches yet. This step is for mapping and approach selection only.
Always present approach options to the user for decision before proceeding to code changes.
```

## Duplication remediation subagent template

After the user has chosen a consolidation approach for each duplication group, use a code-changing subagent.

Prompt shape:

```text
Implement the approved duplication consolidation in <repo-path>.

Inputs:
- duplication group: <file A lines X-Y> duplicated with <file B lines X-Y>
- approved approach: <extract shared utility | base class | composition | other>
- target location for shared code: <path or "create new">
- validation commands: <build, lint, test commands>

Return:
- patch summary
- validation results
- updated duplication line count estimate
- any follow-up risks or new duplication introduced

Do not expand scope beyond the approved duplication group.
```

## Handoff rules

- Keep Sonar fetching, issue ranking, and repo interpretation as separate concerns.
- Prefer parallel subagents for independent data gathering.
- Keep the main agent responsible for final prioritization, user communication, and stop/go decisions.
- If any subagent reports a mismatch between helper output and SonarQube, reconcile that before editing code.

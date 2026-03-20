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

## Handoff rules

- Keep Sonar fetching, issue ranking, and repo interpretation as separate concerns.
- Prefer parallel subagents for independent data gathering.
- Keep the main agent responsible for final prioritization, user communication, and stop/go decisions.
- If any subagent reports a mismatch between helper output and SonarQube, reconcile that before editing code.

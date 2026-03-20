---
name: sonarqube-remediation
description: Fetch and triage SonarQube issues and measures for conservative remediation work by delegating Sonar data gathering to subagents. Use when you need SonarQube Server data such as bugs, code smells, duplicated lines, or quality gate status.
references:
  - references/auth-and-setup.md
  - references/api-usage.md
  - references/remediation-policy.md
  - references/mcp-optional-setup.md
  - references/subagent-workflow.md
---

# SonarQube Remediation

Use this skill when SonarQube should be the source of findings for conservative code cleanup.

This skill is orchestration-first: keep the main agent focused on the user's repo context, implementation history, and final decision-making. Offload Sonar fetches, broad issue listing, and heavy triage passes to subagents so the main context stays intact.

## Workflow you must follow

1. Capture the Sonar scope up front.

   Gather the `project-key`, optional `branch` or `pull-request`, any explicit issue keys, and the local verification commands you expect to run later.

2. Spawn subagents for Sonar data collection instead of doing that work in the main thread.

   Prefer narrow execution-oriented subagents such as a `task` agent when available. Launch independent subagents in parallel when possible:

   - ONE (1) execution-oriented subagent for `sonar_fetch_summary.py`
   - ONE (1) execution-oriented subagent for `sonar_fetch_issues.py`
   - OPTIONAL ONE (1) explore-style subagent to map Sonar findings back to local modules, ownership, or existing code patterns

3. Give each subagent a narrow contract.

   Every Sonar subagent prompt should include:

   - the repo or working directory
   - the exact helper command to run
   - the expected output shape
   - the instruction to rely on existing environment variables rather than copying secrets into prompts
   - the instruction to stop and report if the helper output disagrees with raw API data or the SonarQube UI

4. Reconcile the results in the main agent.

   Treat SonarQube as the source of findings. Deduplicate, rank, and narrow the candidate fixes in the main context before any code changes begin.

5. Only then choose the remediation path.

   - For simple, low-risk fixes, the main agent may patch directly.
   - For nontrivial fixes, hand implementation to a code-changing subagent, then review and verify the result in the main agent.
   - Keep final judgment, user communication, and go/no-go decisions in the main agent.

See [subagent-workflow.md](./references/subagent-workflow.md) for concrete prompt templates.

## Scope

- Use the bundled REST helper scripts to retrieve SonarQube data.
- Treat SonarQube Server as the source of findings.
- Keep tokens, `.env` files, and machine-local MCP config out of commits.
- Use this skill for subagent-oriented data gathering, issue triage inputs, helper commands, and SonarQube-specific reference material.
- Leave final remediation judgment, local verification, commit creation, PR creation, and cleanup decisions to the calling agent.

## Subagent routing

| Need | Recommended subagent role | Return to main agent with |
|------|----------------------------|---------------------------|
| Quality gate and summary metrics | Execution/task subagent | Compact JSON plus notable risk flags |
| Narrow issue list for a project, branch, or issue key set | Execution/task subagent | Filtered findings with rule, severity, location, and issue key |
| Map Sonar paths or rules to local code patterns | Explore subagent | Relevant files, abstractions, and risk notes |
| Implement a nontrivial conservative fix | Code-changing subagent | Patch summary, verification steps, and residual risks |

Launch these in parallel when their inputs do not depend on each other.

## Shell compatibility

- Bash/zsh: use `python3`.
- Windows PowerShell: prefer `py -3`; use `python` only if `py` is unavailable.
- Keep script paths relative and with forward slashes so the same commands work across shells.

## Required environment

- `SONARQUBE_URL`
- `SONARQUBE_TOKEN`
- Subagents should use the caller's existing shell environment. Never paste secret values into prompts, markdown, or commits.

## Quick start

Use these as the exact helper commands passed to the Sonar data-collection subagents.

Project summary:

```bash
python3 .config/shared/skills/sonarqube-remediation/scripts/sonar_fetch_summary.py --project-key <project-key>
```

```powershell
py -3 .config/shared/skills/sonarqube-remediation/scripts/sonar_fetch_summary.py --project-key <project-key>
```

Open issues:

```bash
python3 .config/shared/skills/sonarqube-remediation/scripts/sonar_fetch_issues.py --project-key <project-key> --types BUG,CODE_SMELL --statuses OPEN,CONFIRMED --max-pages 2
```

```powershell
py -3 .config/shared/skills/sonarqube-remediation/scripts/sonar_fetch_issues.py --project-key <project-key> --types BUG,CODE_SMELL --statuses OPEN,CONFIRMED --max-pages 2
```

If the helper output disagrees with the UI or a manual request, compare against this raw API form:

```bash
curl -s -u "$SONARQUBE_TOKEN:" "$SONARQUBE_URL/api/issues/search?componentKeys=<project-key>&types=BUG,CODE_SMELL&statuses=OPEN,CONFIRMED&ps=100"
```

## Conservative decision rules

- Prefer explicitly requested issue keys when provided by the caller.
- Otherwise favor small, local, low-risk fixes over broad cleanup.
- Be cautious with auth, crypto, access control, data migrations, concurrency-sensitive code, and large cross-package duplication work.
- If helper output disagrees with the UI or raw API data, stop and reconcile the mismatch before changing code.
- If the repo cannot locally verify a fix, surface the limitation instead of guessing.

## Optional tooling

- `SonarQube MCP server`: useful for richer agent workflows, but optional here because MCP is global, not per skill.
- `sonar` CLI: useful if installed locally, but not the required contract for this skill.
- `sonar-scanner`: optional for CI-managed analysis, not required for this skill's local workflow.

## Reading order

| Task | Files |
|------|-------|
| Validate auth or shell setup | `references/auth-and-setup.md` |
| Choose API filters or inspect helper output | `references/api-usage.md` |
| Decide whether a fix is safe to automate | `references/remediation-policy.md` |
| Set up optional MCP integration | `references/mcp-optional-setup.md` |
| Write subagent prompts or split work | `references/subagent-workflow.md` |

## In this reference

| File | Purpose |
|------|---------|
| [auth-and-setup.md](./references/auth-and-setup.md) | Environment variables, auth model, and safe local setup |
| [api-usage.md](./references/api-usage.md) | Helper commands, filters, polling, and output contract |
| [remediation-policy.md](./references/remediation-policy.md) | Conservative fix boundaries and do-not-auto-fix guidance |
| [mcp-optional-setup.md](./references/mcp-optional-setup.md) | Optional Sonar MCP setup notes |
| [subagent-workflow.md](./references/subagent-workflow.md) | Prompt templates and role split for preserving main-agent context |
